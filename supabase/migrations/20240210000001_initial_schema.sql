-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Create profiles table
create table if not exists public.profiles (
  id uuid references auth.users not null primary key,
  username text unique,
  avatar_url text,
  updated_at timestamp with time zone,
  
  constraint username_length check (char_length(username) >= 3)
);

-- Set up Row Level Security (RLS) for profiles
alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone."
  on public.profiles for select
  using ( true );

create policy "Users can insert their own profile."
  on public.profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on public.profiles for update
  using ( auth.uid() = id );

-- Create lists table
create table if not exists public.lists (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,
  name text not null,
  color text,
  icon text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Set up RLS for lists
alter table public.lists enable row level security;

create policy "Users can view own lists."
  on public.lists for select
  using ( auth.uid() = user_id );

create policy "Users can insert own lists."
  on public.lists for insert
  with check ( auth.uid() = user_id );

create policy "Users can update own lists."
  on public.lists for update
  using ( auth.uid() = user_id );

create policy "Users can delete own lists."
  on public.lists for delete
  using ( auth.uid() = user_id );

-- Create tasks table
create table if not exists public.tasks (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) not null,
  list_id uuid references public.lists(id),
  title text not null,
  description text,
  due_date timestamp with time zone,
  is_completed boolean default false,
  priority integer default 0, -- 0: None, 1: Low, 2: Medium, 3: High
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Set up RLS for tasks
alter table public.tasks enable row level security;

create policy "Users can view own tasks."
  on public.tasks for select
  using ( auth.uid() = user_id );

create policy "Users can insert own tasks."
  on public.tasks for insert
  with check ( auth.uid() = user_id );

create policy "Users can update own tasks."
  on public.tasks for update
  using ( auth.uid() = user_id );

create policy "Users can delete own tasks."
  on public.tasks for delete
  using ( auth.uid() = user_id );

-- Function to handle new user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, avatar_url)
  values (new.id, new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to call the function on new user creation
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
