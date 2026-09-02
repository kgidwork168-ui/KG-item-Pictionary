# KG Material Pictionary / KG 材料图鉴

One professional GitHub Pages website with:

- Public/client picture catalogue with no prices
- Search by English, Chinese, category, Manual No., size and colour
- Category menu on the left
- Username and password login stored in Supabase
- Admin editing inside the same page
- Main Admin can add and edit other admin users
- Regular admins can edit the Pictionary but cannot manage accounts
- Print or save the client material collection as PDF
- Picture upload to Supabase Storage
- Unique Manual No. for every variant

There is no email login, no separate `admin.html` and no price website.

## Permissions

| User | View catalogue | Edit Pictionary | Add/edit admin users |
|---|---:|---:|---:|
| Public/client | Yes | No | No |
| Admin | Yes | Yes | No |
| Main Admin (`chester`) | Yes | Yes | Yes |

The rules are checked by the secure Supabase function. Public visitors cannot bypass them by changing the webpage.

## 1. Install the database

1. Open your Supabase project.
2. Open **SQL Editor**.
3. Open `supabase-setup.sql` from this folder.
4. Copy everything, paste it into SQL Editor and press **Run**.

## 2. Create Main Admin `chester`

No email address is required.

1. Open `main-admin-setup.sql`.
2. Replace `CHANGE_TO_YOUR_MAIN_ADMIN_PASSWORD` with the Main Admin password.
3. Copy the SQL into the Supabase SQL Editor.
4. Press **Run**.
5. Do not upload the edited copy containing the password to public GitHub.

Supabase stores only the protected password hash. The readable password is not saved in the website code or database.

## 3. Deploy the secure login function

The Pictionary uses one protected Supabase Edge Function for login, account management, material editing and image-upload permission.

From this project folder:

```bash
supabase login
supabase link --project-ref bvfjiequaoqnrglytvfp
supabase functions deploy pictionary-admin
```

The Supabase Service Role key stays inside Supabase. Never place it in `config.js`, GitHub or any browser file.

## 4. Supabase connection

`config.js` is already connected using the supplied publishable key. This key is intended for the browser; the database and function permission checks protect private actions.

## 5. Publish on GitHub Pages

1. Create one GitHub repository.
2. Upload every file and folder from this project. Use the untouched `main-admin-setup.sql` containing the placeholder, not a copy containing the real password.
3. Open **Settings → Pages**.
4. Under **Build and deployment**, choose **GitHub Actions**.
5. The included workflow publishes the website automatically.

Your website address will look like:

`https://YOUR-GITHUB-NAME.github.io/YOUR-REPOSITORY-NAME/`

## Using the website

- Client: browse or search the material list. No login is required.
- Admin: press **Admin / 管理员登录** at the bottom-left and enter username/password.
- Admin: add, edit or delete categories, materials, pictures and variants.
- Main Admin: press **Admin Users / 管理员** to add or edit regular administrators.
- Main Admin can change a regular admin's username, display name, password or active status.
- Regular admins cannot see or use the Admin Users function.
- Admin login automatically expires after 12 hours, and repeated wrong passwords are temporarily blocked.
