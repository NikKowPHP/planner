-- Add soft delete to tasks
alter table public.tasks add column deleted_at timestamp with time zone;

-- Create tags table
create table if not exists public.tags (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,
  name text not null,
  color text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create junction table for task-tags
create table if not exists public.task_tags (
  task_id uuid references public.tasks(id) on delete cascade not null,
  tag_id uuid references public.tags(id) on delete cascade not null,
  primary key (task_id, tag_id)
);

-- RLS for Tags
alter table public.tags enable row level security;

create policy "Users can view own tags." on public.tags for select using ( auth.uid() = user_id );
create policy "Users can insert own tags." on public.tags for insert with check ( auth.uid() = user_id );
create policy "Users can update own tags." on public.tags for update using ( auth.uid() = user_id );
create policy "Users can delete own tags." on public.tags for delete using ( auth.uid() = user_id );

-- RLS for Task Tags
alter table public.task_tags enable row level security;

create policy "Users can view own task tags." on public.task_tags for select using (
  exists (select 1 from public.tasks where id = task_tags.task_id and user_id = auth.uid())
);

create policy "Users can insert own task tags." on public.task_tags for insert with check (
  exists (select 1 from public.tasks where id = task_tags.task_id and user_id = auth.uid())
);

create policy "Users can delete own task tags." on public.task_tags for delete using (
  exists (select 1 from public.tasks where id = task_tags.task_id and user_id = auth.uid())
);
