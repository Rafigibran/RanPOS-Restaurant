# Supabase setup for RanPOS (user's own project)

RanPOS works fully offline without this. Only follow these steps if you
want cloud backup.

## 1. Create a project

Create a project at supabase.com. Note its Project URL and its
publishable key (Settings -> API). Use the publishable key in the app.

NEVER enter a secret key or service_role key in the app, in source
code, or in any file bundled with the app. A service_role key bypasses
Row Level Security and belongs only on a server you control.

## 2. Create a private bucket named ranpos-backups

In Storage, create bucket `ranpos-backups` and keep it PRIVATE.

## 3. Storage policies

Run this SQL in the SQL editor, after enabling Auth for your project.
It restricts each signed-in user to their own `backups/<user-id>/` prefix:

```sql
create policy "Users can upload their own backups"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'ranpos-backups'
  and (storage.foldername(name))[1] = 'backups'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "Users can read their own backups"
on storage.objects for select
to authenticated
using (
  bucket_id = 'ranpos-backups'
  and (storage.foldername(name))[1] = 'backups'
  and (storage.foldername(name))[2] = auth.uid()::text
);
```

If a policy name already exists, adjust the name and re-run.

## 4. In the app

Settings -> Data and Backup -> Supabase:
enter Project URL and publishable key, tap Test Connection,
enter your Supabase Auth email and password, tap Save and Sign In,
then Back Up Now (cloud).

Backup is a snapshot, not realtime sync. Using two devices at the
same time does not merge changes automatically. Restore replaces
local data after confirmation.

## Backup format

JSON, `format: ranpos-backup`, `backup_schema_version: 1`,
with business, categories, menu, customers, floors, tables, orders,
order items, payments, stock movements, notifications and settings.
No session tokens, passwords or API keys are included in the file.
