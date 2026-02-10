-- Create habits table
create table if not exists public.habits (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,
  name text not null,
  icon text, -- e.g., code point or name
  color text, -- Hex string
  goal_value integer default 1, -- Target count per day
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  deleted_at timestamp with time zone
);

-- Create habit logs (completions)
create table if not exists public.habit_logs (
  id uuid default uuid_generate_v4() primary key,
  habit_id uuid references public.habits(id) on delete cascade not null,
  completed_at date not null, -- We only care about the date part
  value integer default 1, -- For habits with count > 1
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(habit_id, completed_at)
);

-- RLS for Habits
alter table public.habits enable row level security;

create policy "Users can view own habits." on public.habits for select using ( auth.uid() = user_id );
create policy "Users can insert own habits." on public.habits for insert with check ( auth.uid() = user_id );
create policy "Users can update own habits." on public.habits for update using ( auth.uid() = user_id );
create policy "Users can delete own habits." on public.habits for delete using ( auth.uid() = user_id );

-- RLS for Logs
alter table public.habit_logs enable row level security;

create policy "Users can view own habit logs." on public.habit_logs for select using (
  exists (select 1 from public.habits where id = habit_logs.habit_id and user_id = auth.uid())
);
create policy "Users can insert own habit logs." on public.habit_logs for insert with check (
  exists (select 1 from public.habits where id = habit_logs.habit_id and user_id = auth.uid())
);
create policy "Users can update own habit logs." on public.habit_logs for update using (
  exists (select 1 from public.habits where id = habit_logs.habit_id and user_id = auth.uid())
);
create policy "Users can delete own habit logs." on public.habit_logs for delete using (
  exists (select 1 from public.habits where id = habit_logs.habit_id and user_id = auth.uid())
);
