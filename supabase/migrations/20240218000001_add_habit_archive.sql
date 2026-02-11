-- Add archive support to habits
alter table public.habits add column is_archived boolean default false;
