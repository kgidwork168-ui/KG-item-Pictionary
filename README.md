# KG Material Catalogue — GitHub Pages + Supabase

A simple public bilingual catalogue for ceiling and partition materials.

## What it does

### Public page
- No login required
- View all items
- Search English / Chinese names
- Filter by category
- See item photo, name, size, colour, price and price unit
- Phone friendly

### Admin page
- Email + password login
- Only approved admins can add/edit/delete
- Add/edit categories
- Add/edit products
- Upload/replace product photo
- Edit price
- Public users cannot write to the database because Supabase RLS blocks them

## Files

- `index.html` — public catalogue
- `admin.html` — admin page
- `css/styles.css` — design
- `js/config.js` — Supabase URL + Publishable Key
- `js/catalog.js` — public catalogue logic
- `js/admin.js` — admin logic
- `supabase-setup.sql` — database + security + storage setup

# DONKEY STEPS / 简单步骤

## STEP 1 — Create Supabase project

1. Go to Supabase and create a new project.
2. Wait until the project is ready.
3. Open **SQL Editor**.
4. Copy ALL of `supabase-setup.sql`.
5. Paste it into SQL Editor.
6. Click **Run**.

## STEP 2 — Create your admin login

1. In Supabase, open **Authentication** -> **Users**.
2. Add a new user using your admin email and password.
3. Copy the user's UUID.
4. Go back to **SQL Editor**.
5. Run:

```sql
insert into public.admin_users (user_id)
values ('PASTE-ADMIN-USER-UUID-HERE')
on conflict do nothing;
```

Only UUIDs inside `admin_users` are allowed to edit catalogue data.

## STEP 3 — Connect website to Supabase

1. In Supabase open **Project Settings** -> **API**.
2. Copy:
   - Project URL
   - Publishable key (or legacy anon key)
3. Open `js/config.js`.
4. Replace:

```js
SUPABASE_URL: "PASTE_YOUR_SUPABASE_URL_HERE",
SUPABASE_KEY: "PASTE_YOUR_SUPABASE_PUBLISHABLE_KEY_HERE",
```

IMPORTANT: Never put the `service_role` / secret key in GitHub Pages.

## STEP 4 — Put on GitHub Pages

1. Create a GitHub repository, for example `kg-material-catalogue`.
2. Upload all the files and folders from this project.
3. Commit them to the `main` branch.
4. Open repository **Settings** -> **Pages**.
5. Under **Build and deployment** choose:
   - Source: **Deploy from a branch**
   - Branch: **main**
   - Folder: **/(root)**
6. Save.
7. Open the GitHub Pages URL after deployment.

Public page:
`https://YOUR-USERNAME.github.io/kg-material-catalogue/`

Admin page:
`https://YOUR-USERNAME.github.io/kg-material-catalogue/admin.html`

The admin page URL is not the security. Supabase RLS is the security.

## Recommended first categories

- Board / 板材
- Wall Plug / 墙塞
- Wood Board / 木板
- Metal / 金属
- Screw / 螺丝

You can change/add/delete categories from the Admin page.

## Security

This project intentionally uses the Supabase Publishable/anon key in the browser. This is normal for a browser app. Protection comes from Row Level Security (RLS). The `service_role` key must never be placed in browser code or GitHub.
