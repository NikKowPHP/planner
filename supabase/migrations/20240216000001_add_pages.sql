-- Create pages table

create table if not exists public.pages (

  id uuid default uuid_generate_v4() primary key,

  user_id uuid references public.profiles(id) not null,

  parent_id uuid references public.pages(id) on delete cascade, -- Self-referencing for nesting

  title text not null default 'Untitled',

  content text default '', -- Markdown content

  icon text, -- Emoji or icon code

  is_expanded boolean default false, -- UI state for sidebar tree

  created_at timestamp with time zone default timezone('utc'::text, now()) not null,

  updated_at timestamp with time zone default timezone('utc'::text, now()) not null

);



-- RLS

alter table public.pages enable row level security;



create policy "Users can view own pages." on public.pages for select using ( auth.uid() = user_id );

create policy "Users can insert own pages." on public.pages for insert with check ( auth.uid() = user_id );

create policy "Users can update own pages." on public.pages for update using ( auth.uid() = user_id );

create policy "Users can delete own pages." on public.pages for delete using ( auth.uid() = user_id );

