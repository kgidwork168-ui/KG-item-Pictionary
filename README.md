# KG Material Pictionary — NO PRICE

This is one of TWO separate GitHub Pages repositories.

## Layout

The website now follows an app-style layout:
- Dark category navigation on the LEFT
- Search bar at the TOP
- Admin Login at the BOTTOM-LEFT
- Materials displayed as clean rows
- Picture is visible immediately
- All variants are visible immediately
- NO click into an item is needed

Each variant can have:
- Unique Manual No.
- Size (optional)
- Colour (optional)
- Price (optional)
- Unit (optional)

This site NEVER requests `price` or `price_unit` in its Supabase catalogue query. It displays every other item/variant detail but no price.

## Shared Supabase

Both GitHub repositories MUST use the SAME values inside `js/config.js`:

- `SUPABASE_URL`
- `SUPABASE_KEY`

That means an Admin edit is made once and both websites update from the same database.

Example:
Admin changes CS001 from `9mm` to `9.5mm`.
- Price website shows `9.5mm`
- No-price website also shows `9.5mm`
- Only the price website displays the price.

## Setup

1. Supabase -> SQL Editor
2. Run `supabase-setup-or-upgrade.sql`
3. Supabase -> Authentication -> Users -> Add User
4. Copy the User UUID
5. Run:

```sql
insert into public.admin_users(user_id)
values('PASTE-ADMIN-USER-UUID-HERE')
on conflict do nothing;
```

6. Supabase -> Project Settings -> API
7. Put the SAME Project URL + Publishable Key in `js/config.js` for BOTH repositories.
8. Upload each repository to its own GitHub repository.
9. GitHub -> Settings -> Pages -> Deploy from branch -> `main` -> `/(root)`.

## Admin

Open `admin.html` or click **Admin Login / 管理员登录** at the bottom-left.

Admin can:
- Add/edit categories
- Add/edit/delete material items
- Upload or replace image
- Remove image
- Add unlimited variants
- Edit Manual No.
- Edit Size
- Edit Colour
- Edit Price
- Edit Unit

Manual No. is checked as unique.
