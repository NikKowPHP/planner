-- Create custom_filters table
create table if not exists public.custom_filters (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,
  name text not null,
  icon text, -- Store icon code point or name
  color text,
  criteria jsonb not null default '{}'::jsonb, -- Stores { priorities: [], list_ids: [], date_range: '...', etc }
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS
alter table public.custom_filters enable row level security;

create policy "Users can view own filters." on public.custom_filters for select using ( auth.uid() = user_id );
create policy "Users can insert own filters." on public.custom_filters for insert with check ( auth.uid() = user_id );
create policy "Users can update own filters." on public.custom_filters for update using ( auth.uid() = user_id );
create policy "Users can delete own filters." on public.custom_filters for delete using ( auth.uid() = user_id );
