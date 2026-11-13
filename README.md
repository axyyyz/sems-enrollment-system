# SEMS: Student Information and Enrollment Management System

Final project for **Platform Technologies** (Topic 10).
**Group members:** Name 1, Name 2, Name 3
**Live site:** paste your GitHub Pages link here

## What it does
Students register, pick subjects, submit an enrollment, download an enrollment slip and view their grades. Admins record payments, approve or reject enrollments, post grades, manage subjects and users, and watch a dashboard with charts.

## Architecture
Browser (HTML, CSS, JavaScript) to the **supabase-js SDK** to **Supabase** (REST API over HTTPS with JSON, Auth and PostgreSQL).
- **Auth:** Supabase Auth with email and password. Students self register and a database trigger creates a Student profile and Student ID.
- **Database:** PostgreSQL tables `profiles, subjects, enrollments, enrollment_items, grades, audit_log` in `schema.sql`.
- **Security:** Row Level Security. Clients only read what their role allows and there are no direct write policies.
- **Business logic in the database:** `submit_enrollment`, `record_payment`, `decide_enrollment`, `post_grade` and the admin functions are called as RPC endpoints. They check the role, prerequisites, the 21 unit load, and that an enrollment cannot be approved until payment is recorded.

## Platform technologies
| Category | Technology | Purpose in SEMS |
|---|---|---|
| Cloud service | Supabase | Hosts the PostgreSQL database and authentication so no server of our own is needed |
| SDK | supabase-js | Lets the browser sign users in and call the database with simple functions |
| API and web service | Supabase REST (PostgREST) and RPC endpoints | Carries enrollment, payment, approval and grading requests |
| Interoperability | JSON over HTTPS | Standard format used between the page and the backend |
| Library | Chart.js | Draws the admin dashboard charts for enrollment status and enrollments per subject |
| Library | jsPDF | Generates the downloadable enrollment slip for students |
| Plug-in | DataTables on jQuery | Adds search, sorting and paging to the admin tables |
| Version control | Git and GitHub Pages | Group collaboration, commit history and hosting of the live site |

That is eight components across six categories.

## Setup
1. Create a free project at supabase.com.
2. Go to **SQL Editor, New query**, paste all of `schema.sql` and click **Run**.
3. Run `admin_only.sql` the same way.
4. Go to **Authentication, Providers, Email** and turn on "Confirm email" so new students must verify their email. Set up custom SMTP under **Authentication, Emails, SMTP Settings** so the emails reach every student. For quick demos you can turn confirmation off.
5. Go to **Project Settings, API** and copy the **Project URL** and **anon public key** into `CFG` at the top of the script in `index.html`. The anon key is meant to be public because security comes from Row Level Security. Never put the `service_role` key in the page.
6. Open `index.html` or deploy it to GitHub Pages and register a student account.
7. After deploying, set **Authentication, URL Configuration, Site URL** to your GitHub Pages link.

## Roles
There are two roles, **Student** and **Admin**. Everyone who registers is a Student. To make the first Admin, register on the site, then run this in the SQL Editor with your email:
```sql
update profiles set role='Admin', student_no=null where email='your-email@example.com';
```
Log out and in again. More Admins can be created from the **Users** tab.

## Testing
Record each test case with the input, expected result, actual result and a screenshot. Examples:
- Register with a weak password: rejected.
- Enroll without the prerequisite: rejected.
- Admin approves an unpaid enrollment: rejected.
- Student reads another student's data: no rows because of RLS.
- Student downloads the enrollment slip: PDF is generated.
- Admin searches and sorts a table: results update.

## Limitations
No email notifications, no password reset screen and a single term.
