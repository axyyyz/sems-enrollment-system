-- SEMS database schema for Supabase (PostgreSQL). Run once in: Supabase > SQL Editor > New query.

create table profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  email text, full_name text not null default '', program text not null default '',
  role text not null default 'Student' check (role in ('Student','Registrar','Cashier','Faculty')),
  student_no text unique, created_at timestamptz default now());

create table subjects(
  code text primary key, title text not null, units int not null check (units>0),
  prereq text references subjects(code), faculty_id uuid references profiles(id));

create table enrollments(
  id bigint generated always as identity primary key,
  student_id uuid not null references profiles(id),
  status text not null default 'Pending' check (status in ('Pending','Approved','Rejected')),
  fee numeric not null, paid boolean not null default false, or_no text, note text default '',
  created_at timestamptz default now());

create table enrollment_items(
  enrollment_id bigint references enrollments(id) on delete cascade,
  subject_code text references subjects(code),
  primary key (enrollment_id, subject_code));

create table grades(
  student_id uuid references profiles(id), subject_code text references subjects(code),
  grade numeric not null check (grade between 1 and 5), posted_by uuid references profiles(id),
  primary key (student_id, subject_code));

create table audit_log(
  id bigint generated always as identity primary key,
  actor uuid references profiles(id), action text not null, created_at timestamptz default now());

-- Student self-registration: every new auth user gets a Student profile with an auto-generated Student ID.
create sequence student_seq start 1;
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,email,full_name,program,role,student_no) values(
    new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name',''),coalesce(new.raw_user_meta_data->>'program',''),
    'Student',extract(year from now())::int||'-'||lpad(nextval('student_seq')::text,4,'0'));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

create function my_role() returns text language sql security definer stable set search_path=public as
$$ select role from profiles where id=auth.uid() $$;

-- Row Level Security: clients can only READ what their role allows; all writes go through the functions below.
alter table profiles enable row level security;
alter table subjects enable row level security;
alter table enrollments enable row level security;
alter table enrollment_items enable row level security;
alter table grades enable row level security;
alter table audit_log enable row level security;

create policy profiles_read on profiles for select to authenticated using (id=auth.uid() or my_role() in ('Registrar','Cashier','Faculty'));
create policy subjects_read on subjects for select to authenticated using (true);
create policy enroll_read on enrollments for select to authenticated using (student_id=auth.uid() or my_role() in ('Registrar','Cashier','Faculty'));
create policy items_read on enrollment_items for select to authenticated using (exists(select 1 from enrollments e where e.id=enrollment_id and (e.student_id=auth.uid() or my_role() in ('Registrar','Cashier','Faculty'))));
create policy grades_read on grades for select to authenticated using (student_id=auth.uid() or my_role() in ('Registrar','Faculty'));
create policy audit_read on audit_log for select to authenticated using (my_role()='Registrar');

-- Business rules enforced in the database (server side)
create function submit_enrollment(codes text[]) returns void language plpgsql security definer set search_path=public as $$
declare u int; eid bigint; c text; p text;
begin
  if my_role() is distinct from 'Student' then raise exception 'Only students can enroll'; end if;
  if coalesce(array_length(codes,1),0)=0 then raise exception 'Select at least one subject'; end if;
  if exists(select 1 from enrollments where student_id=auth.uid() and status<>'Rejected') then raise exception 'You already have an active enrollment'; end if;
  select coalesce(sum(units),0) into u from subjects where code=any(codes);
  if u>21 then raise exception 'Maximum load is 21 units'; end if;
  foreach c in array codes loop
    select prereq into p from subjects where code=c;
    if not found then raise exception 'Unknown subject %',c; end if;
    if exists(select 1 from grades where student_id=auth.uid() and subject_code=c and grade<=3) then raise exception '% is already passed',c; end if;
    if p is not null and not exists(select 1 from grades where student_id=auth.uid() and subject_code=p and grade<=3) then raise exception '% requires passing %',c,p; end if;
  end loop;
  insert into enrollments(student_id,fee) values(auth.uid(),u*1000+1500) returning id into eid;
  insert into enrollment_items select distinct eid,x from unnest(codes) x;
  insert into audit_log(actor,action) values(auth.uid(),'Submitted enrollment #'||eid);
end $$;

create function record_payment(eid bigint, or_no text) returns void language plpgsql security definer set search_path=public as $$
begin
  if my_role() is distinct from 'Cashier' then raise exception 'Only the Cashier can record payments'; end if;
  if or_no !~ '^[A-Za-z0-9-]{4,20}$' then raise exception 'Enter a valid OR number (4-20 letters, digits or dashes)'; end if;
  update enrollments set paid=true, or_no=record_payment.or_no where id=eid and paid=false;
  if not found then raise exception 'Enrollment not found or already paid'; end if;
  insert into audit_log(actor,action) values(auth.uid(),'Recorded payment '||or_no||' for enrollment #'||eid);
end $$;

create function decide_enrollment(eid bigint, approve boolean, note text) returns void language plpgsql security definer set search_path=public as $$
begin
  if my_role() is distinct from 'Registrar' then raise exception 'Only the Registrar can decide enrollments'; end if;
  if approve and not (select paid from enrollments where id=eid) then raise exception 'Cannot approve: payment not yet verified by the Cashier'; end if;
  if not approve and coalesce(trim(note),'')='' then raise exception 'Give a reason for rejecting'; end if;
  update enrollments set status=case when approve then 'Approved' else 'Rejected' end, note=coalesce(note,'') where id=eid and status='Pending';
  if not found then raise exception 'Enrollment not found or already decided'; end if;
  insert into audit_log(actor,action) values(auth.uid(),case when approve then 'Approved' else 'Rejected' end||' enrollment #'||eid);
end $$;

create function post_grade(sid uuid, code text, g numeric) returns void language plpgsql security definer set search_path=public as $$
begin
  if my_role() is distinct from 'Faculty' then raise exception 'Only Faculty can post grades'; end if;
  if g<1 or g>5 then raise exception 'Grade must be between 1.0 and 5.0'; end if;
  if not exists(select 1 from subjects where subjects.code=post_grade.code and faculty_id=auth.uid()) then raise exception 'You do not handle this subject'; end if;
  if not exists(select 1 from enrollments e join enrollment_items i on i.enrollment_id=e.id where e.student_id=sid and e.status='Approved' and i.subject_code=post_grade.code) then raise exception 'Student is not officially enrolled in this subject'; end if;
  insert into grades(student_id,subject_code,grade,posted_by) values(sid,code,g,auth.uid())
    on conflict (student_id,subject_code) do update set grade=excluded.grade, posted_by=excluded.posted_by;
  insert into audit_log(actor,action) values(auth.uid(),'Posted grade '||g||' for '||code);
end $$;

insert into subjects(code,title,units,prereq) values
 ('ITEC101','Introduction to Computing',3,null),('ITEC102','Computer Programming 1',3,null),
 ('ITEC103','Computer Programming 2',3,'ITEC102'),('ITEC104','Web Systems and Technologies',3,'ITEC101'),
 ('ITEC205','Information Management',3,'ITEC103'),('PLAT301','Platform Technologies',3,'ITEC205'),
 ('GEC101','Understanding the Self',3,null);
