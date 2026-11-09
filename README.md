# SEMS – Student Information and Enrollment Management System

Final project for **Platform Technologies** (Topic 10).
**Group members:** _Name 1_, _Name 2_, _Name 3_  |  **Live site:** _GitHub Pages link_

## Architecture
Browser (HTML/CSS/JS) → **supabase-js SDK** → **Supabase** (REST API over HTTPS/JSON, Auth, PostgreSQL).
- **Auth:** Supabase Auth (email + password, hashed server-side). Students self-register; a database trigger creates a Student profile and Student ID.
- **Database:** PostgreSQL tables `profiles, subjects, enrollments, enrollment_items, grades, audit_log` (see `schema.sql`).
- **Security:** Row Level Security. Clients can only read what their role allows; there are no direct write policies.
- **Business logic in the database:** `submit_enrollment`, `record_payment`, `decide_enrollment`, `post_grade` (called as REST RPC endpoints). They check the user's role, prerequisites, the 21-unit load, and that the Admin cannot approve an enrollment until its payment is recorded.

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

## Roles
There are two roles: **Student** and **Admin**. Everyone who registers on the site is a Student. The Admin handles enrollments (recording payments and approving or rejecting), posting grades, managing subjects and managing users.
1. Run `schema.sql`, then `admin_only.sql` in the Supabase SQL Editor.
2. Register on the site, then make yourself the first Admin (replace the email):
```sql
update profiles set role='Admin', student_no=null where email='your-email@example.com';
```
3. Log out and in again. Other Admins can be created from the **Users** tab.
To let a new student enroll in higher subjects without earlier grades, post grades for the prerequisite subjects or insert test rows into `grades`.

## Testing
Record each test case (input, expected result, actual result, screenshot) in a table, e.g.: register with a weak password → rejected; enroll without prerequisite → rejected; Registrar approves unpaid enrollment → rejected; student reads another student's data → no rows (RLS).

## Limitations
no email notifications; no password-reset screen (Supabase supports it); single term.
