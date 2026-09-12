-- PuraLink Dashboard — Schema v2 (staff write access, doctor read-only access)
-- Run this in Supabase SQL Editor on a fresh project.

-- 1. Doctors table — your customers, view-only access to their own data
create table doctors (
  id uuid references auth.users(id) primary key,
  full_name text not null,
  email text not null,
  created_at timestamp with time zone default now()
);

-- 2. Staff table — your employees, full read/write access
-- NOTE: staff accounts are NOT created through public self-registration.
-- You create the login yourself (via the private staff signup page, or
-- directly in Supabase Authentication), then their row here is created
-- automatically by that signup — but only people you give the staff
-- signup link to should ever use it.
create table staff (
  id uuid references auth.users(id) primary key,
  full_name text not null,
  email text not null,
  created_at timestamp with time zone default now()
);

-- 3. Patients table
create table patients (
  id uuid default gen_random_uuid() primary key,
  doctor_id uuid references doctors(id) not null,
  patient_label text not null,        -- non-identifying label, e.g. "Case 0442"
  chronic_condition text not null,
  created_at timestamp with time zone default now()
);

-- 4. Follow-ups table
create table follow_ups (
  id uuid default gen_random_uuid() primary key,
  patient_id uuid references patients(id) not null,
  month text not null,                -- format: '2026-09'
  status text not null check (status in ('completed', 'pending')) default 'pending',
  notes text,
  updated_by uuid references staff(id),
  created_at timestamp with time zone default now()
);

-- 5. Enable Row Level Security on everything
alter table doctors enable row level security;
alter table staff enable row level security;
alter table patients enable row level security;
alter table follow_ups enable row level security;

-- 6. Doctors: can VIEW only their own record and their own patients/follow-ups.
--    No insert/update/delete rights at all.

create policy "Doctors view own record"
  on doctors for select
  using (auth.uid() = id);

create policy "Doctors view own patients"
  on patients for select
  using (auth.uid() = doctor_id);

create policy "Doctors view own follow-ups"
  on follow_ups for select
  using (
    auth.uid() = (select doctor_id from patients where patients.id = follow_ups.patient_id)
  );

-- 7. Staff: full access to manage all patients and follow-ups.

create policy "Staff view own record"
  on staff for select
  using (auth.uid() = id);

create policy "Staff view all doctors"
  on doctors for select
  using (exists (select 1 from staff where staff.id = auth.uid()));

create policy "Staff manage all patients"
  on patients for all
  using (exists (select 1 from staff where staff.id = auth.uid()));

create policy "Staff manage all follow-ups"
  on follow_ups for all
  using (exists (select 1 from staff where staff.id = auth.uid()));
