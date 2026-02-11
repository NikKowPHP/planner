-- Add reminder_time to habits (Stored as "HH:mm" string)
alter table public.habits add column reminder_time text;
