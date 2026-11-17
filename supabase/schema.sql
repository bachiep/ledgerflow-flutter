-- LedgerFlow Supabase Postgres Schema + Row-Level Security (RLS)
-- Apply inside the Supabase SQL Editor before running with --dart-define=SUPABASE_URL / SUPABASE_ANON_KEY.

create table if not exists public.wallets (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  currency text not null default 'VND',
  initial_balance_minor bigint not null default 0,
  is_shared boolean not null default false,
  updated_at_epoch_ms bigint not null,
  deleted_at_epoch_ms bigint,
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  type text not null check (type in ('income', 'expense')),
  icon_name text not null,
  color_hex bigint not null,
  monthly_budget_minor bigint not null default 0,
  updated_at_epoch_ms bigint not null
);

create table if not exists public.transactions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  wallet_id uuid not null references public.wallets (id) on delete cascade,
  category_id uuid not null references public.categories (id),
  type text not null check (type in ('income', 'expense')),
  amount_minor bigint not null check (amount_minor > 0),
  note text not null default '',
  occurred_at_epoch_ms bigint not null,
  updated_at_epoch_ms bigint not null,
  deleted_at_epoch_ms bigint,
  updated_at timestamptz not null default now()
);

create index if not exists idx_remote_wallets_user_updated
  on public.wallets (user_id, updated_at_epoch_ms);

create index if not exists idx_remote_transactions_user_updated
  on public.transactions (user_id, updated_at_epoch_ms);

alter table public.wallets enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;

create policy "Users manage their own wallets"
  on public.wallets
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage their own categories"
  on public.categories
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage their own transactions"
  on public.transactions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
