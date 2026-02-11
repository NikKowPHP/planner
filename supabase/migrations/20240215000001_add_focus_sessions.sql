-- Create focus_sessions table
create table if not exists public.focus_sessions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,
  task_id uuid references public.tasks(id) on delete set null,
  habit_id uuid references public.habits(id) on delete set null,
  start_time timestamp with time zone not null,
  end_time timestamp with time zone not null,
  duration_seconds integer not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS
alter table public.focus_sessions enable row level security;

create policy "Users can view own focus sessions." on public.focus_sessions for select using ( auth.uid() = user_id );
create policy "Users can insert own focus sessions." on public.focus_sessions for insert with check ( auth.uid() = user_id );
create policy "Users can delete own focus sessions." on public.focus_sessions for delete using ( auth.uid() = user_id );
