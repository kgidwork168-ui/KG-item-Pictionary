# KG Material Pictionary / KG 材料图鉴

One GitHub Pages website with:

- Public picture catalogue with **no prices**
- Search by English, Chinese, category, Manual No., size and colour
- Category menu on the left
- Admin Login at the bottom-left
- Admin editing inside the same page
- Professional client-facing material presentation
- Print or save the material collection as PDF
- Picture upload to Supabase Storage
- Every variant can have its own unique Manual No., size and colour
- Size and colour may be left blank

There is no separate `admin.html` and no price website.

## 1. Set up Supabase

1. Open your Supabase project.
2. Open **SQL Editor**.
3. Copy everything from `supabase-setup.sql` and click **Run**.
4. Go to **Authentication → Users → Add user** and create the admin email and password.
5. Copy the new user's UUID.
6. Run this in SQL Editor, replacing the example UUID:

```sql
insert into public.admins (user_id)
values ('PASTE-AUTH-USER-UUID-HERE');
```

The setup SQL is safe for the earlier database: it adds missing Manual No. and colour columns before creating the unique Manual No. rule. Existing price columns may remain in Supabase, but this website never requests, edits, searches or displays them.

## 2. Connect the website

Open `config.js` and replace:

```js
SUPABASE_URL: "YOUR_SUPABASE_PROJECT_URL",
SUPABASE_ANON_KEY: "YOUR_SUPABASE_PUBLISHABLE_KEY"
```

Use only the Supabase **Publishable/anon key**. Never use the `service_role` key in GitHub.

## 3. Publish on GitHub Pages

1. Create one new GitHub repository.
2. Upload every file and folder from this project.
3. Open **Settings → Pages**.
4. Under **Build and deployment**, choose **GitHub Actions**.
5. The included workflow publishes the site automatically.

Your website will be:

`https://YOUR-GITHUB-NAME.github.io/YOUR-REPOSITORY-NAME/`

## How to use

- Public user: open website, search or choose a category, and view all item details.
- Admin: press **Admin Login / 管理员登录** at the bottom-left.
- After login: use **Add Item**, **Categories**, or the edit/delete buttons on an item.
- Press the same bottom-left button to log out.

## Database safety

Public users have read-only access through Supabase Row Level Security. Only user UUIDs entered in the `admins` table can add, edit, delete or upload pictures.
