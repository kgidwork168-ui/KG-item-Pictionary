# KG Material Catalogue PRO

Professional, simple, phone-friendly ceiling & partition material catalogue using only GitHub Pages + Supabase.

## Public Page 1 - Material Catalogue / 材料图鉴
File: `index.html`

Purpose: identify the item by picture.

Shows:
- big item photo
- category
- English name
- Chinese name
- number of sizes / colours available
- one button to open the exact price

It deliberately does not show a messy price table on the picture page.

## Public Page 2 - Price List / 价格表
File: `prices.html`

Purpose: find the exact price quickly.

One item stays grouped together. Under it you can add unlimited price options:

- Size + Colour + Price
- Size + Price (no colour)
- Colour + Price (no size)
- Price only (no size and no colour)

Empty Size/Colour fields are automatically hidden from the public page.

### Example
Calcium Silicate Board / 硅酸钙板
- 9mm | White | $12.00 / sheet
- 12mm | White | $15.00 / sheet
- 12mm | Green | $18.00 / sheet

Wall Plug / 墙塞
- Red | $8.00 / box

Adhesive / 胶水
- $6.50 / tube

## Admin Page
File: `admin.html`

Only approved admins can:
- add/edit/delete categories
- add/edit/delete materials
- upload/replace images
- add unlimited size/colour/price combinations per item

Public users cannot write because Supabase Row Level Security blocks writes.

# DONKEY SETUP

## 1. Supabase
Create a project -> SQL Editor -> paste all of `supabase-setup.sql` -> Run.

## 2. Create Admin
Supabase -> Authentication -> Users -> Add User.
Copy the user UUID.
Run:

```sql
insert into public.admin_users(user_id)
values('PASTE-ADMIN-USER-UUID-HERE')
on conflict do nothing;
```

## 3. Connect Website
Supabase -> Project Settings -> API.
Copy Project URL and Publishable key.
Open `js/config.js` and replace the two PASTE values.

Never put a service-role/secret key in GitHub Pages.

## 4. GitHub Pages
Upload all files to a GitHub repository.
Repository -> Settings -> Pages -> Deploy from a branch -> main -> /(root).

Pages:
- `/` = Material Catalogue
- `/prices.html` = Price List
- `/admin.html` = Admin

## If you already used my first V1 version
1. Run the new `supabase-setup.sql` first.
2. Then run `upgrade-from-v1.sql` once.
3. Your old single Size / Colour / Price will be copied into the new price-option system.
4. Upload the new website files to GitHub.
