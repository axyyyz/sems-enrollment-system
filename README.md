# SEMS – Student Information and Enrollment Management System

Final project for **Platform Technologies** (Topic 10).
**Group members:** _Name 1_, _Name 2_, _Name 3_  |  **Live site:** _GitHub Pages link_

## Architecture
Browser (HTML/CSS/JS) → **supabase-js SDK** → **Supabase** (REST API over HTTPS/JSON, Auth, PostgreSQL).
- **Auth:** Supabase Auth (email + password, hashed server-side). Students self-register; a database trigger creates a Student profile and Student ID.
- **Database:** PostgreSQL tables `profiles, subjects, enrollments, enrollment_items, grades, audit_log` (see `schema.sql`).
- **Security:** Row Level Security. Clients can only read what their role allows; there are no direct write policies.
- **Business logic in the database:** `submit_enrollment`, `record_payment`, `decide_enrollment`, `post_grade` (called as REST RPC endpoints). They check the user's role, prerequisites, the 21-unit load, and that the Registrar cannot approve until the Cashier records payment.

## Platform technologies (for your documentation)
| Category | Technology | Purpose |
|---|---|---|
| Cloud service | Supabase (PostgreSQL, Auth, hosted API) | Database, authentication, hosting of the backend |
| SDK | supabase-js | Accessing Auth, database and RPC from the browser |
| API / web service | Supabase REST (PostgREST) + RPC endpoints | Data exchange between the front end and the database |
| Interoperability | JSON over HTTPS | Standard data format between components |
| Version control | Git + GitHub (GitHub Pages hosting) | Collaboration, history and deployment |

## Setup
1. Create a free project at supabase.com.
2. **SQL Editor → New query**, paste all of `schema.sql`, click **Run**.
3. **Authentication → Providers → Email**: turn off "Confirm email" (easier for demos and your defense).
4. **Project Settings → API**: copy the **Project URL** and the **anon public key** into `CFG` at the top of the script in `index.html`. (The anon key is meant to be public; security comes from Row Level Security. Never put the `service_role` key in the page.)
5. Open `index.html` (or deploy to GitHub Pages) and register a student account.
6. After deploying, set **Authentication → URL Configuration → Site URL** to your GitHub Pages link.

## Creating staff accounts (Registrar, Cashier, Faculty)
Staff cannot self-register. Register each staff member in the app first, then run in the SQL Editor:
```sql
update profiles set role='Registrar', student_no=null where email='registrar@example.com';
update profiles set role='Cashier',   student_no=null where email='cashier@example.com';
update profiles set role='Faculty',   student_no=null where email='faculty@example.com';
-- assign subjects to the faculty member:
update subjects set faculty_id=(select id from profiles where email='faculty@example.com')
 where code in ('ITEC103','ITEC104','ITEC205','PLAT301');
```
To let students enroll in higher subjects without prior grades, post grades as Faculty (or insert test rows in `grades`).

## Testing
Record each test case (input, expected result, actual result, screenshot) in a table, e.g.: register with a weak password → rejected; enroll without prerequisite → rejected; Registrar approves unpaid enrollment → rejected; student reads another student's data → no rows (RLS).

## Limitations
Staff accounts are created via SQL; no email notifications; no password-reset screen (Supabase supports it); single term.
