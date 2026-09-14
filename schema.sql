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
  target_followup integer not null default 0 check (target_followup >= 0),
  created_at timestamp with time zone default now()
);

-- 3. Admin table — authenticated users allowed to monitor the whole system.
create table admins (
  id uuid references auth.users(id) primary key,
  full_name text not null,
  email text not null,
  created_at timestamp with time zone default now()
);

-- 4. Patients table
create table patients (
  id uuid default gen_random_uuid() primary key,
  doctor_id uuid references doctors(id) not null,
  patient_label text not null,        -- non-identifying label, e.g. "Case 0442"
  chronic_condition text not null,
  created_at timestamp with time zone default now()
);

-- 5. Follow-ups table
create table follow_ups (
  id uuid default gen_random_uuid() primary key,
  patient_id uuid references patients(id) not null,
  month text not null,                -- format: '2026-09'
  status text not null check (status in ('completed', 'pending', 'in_progress')) default 'pending',
  approval_status text not null check (approval_status in ('pending', 'approved', 'rejected')) default 'pending',
  critical_condition text not null check (critical_condition in ('none', 'critical')) default 'none',
  critical_note text,
  notes text,
  assigned_staff_id uuid references staff(id),
  updated_by uuid references staff(id),
  created_at timestamp with time zone default now()
);

-- Migration for an existing database. Assignment is separate from the last editor.
alter table follow_ups add column if not exists assigned_staff_id uuid references staff(id);
alter table follow_ups drop constraint if exists follow_ups_status_check;
alter table follow_ups
  add constraint follow_ups_status_check check (status in ('completed', 'pending', 'in_progress'));

-- A patient has one follow-up status per month. This prevents duplicate rows
-- when staff members update the same patient.
alter table follow_ups
  add constraint follow_ups_patient_month_key unique (patient_id, month);

-- 6. Indexes for dashboard search and patient ownership lookups.
create extension if not exists pg_trgm;
create index patients_doctor_id_idx on patients (doctor_id);
create index patients_patient_label_trgm_idx on patients using gin (patient_label gin_trgm_ops);
create index follow_ups_assigned_staff_id_idx on follow_ups (assigned_staff_id);

-- 7. Enable Row Level Security on everything
alter table doctors enable row level security;
alter table staff enable row level security;
alter table admins enable row level security;
alter table patients enable row level security;
alter table follow_ups enable row level security;

-- RLS policies filter rows, but authenticated users also need table privileges.
grant select on doctors, staff, admins, patients, follow_ups to authenticated;
grant insert, update, delete on patients, follow_ups to authenticated;
grant update (target_followup) on staff to authenticated;

-- 8. Doctors: can VIEW only their own record and their own patients/follow-ups.
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

-- 9. Staff and admins: full access to manage all patients and follow-ups.

create policy "Staff view own record"
  on staff for select
  using (auth.uid() = id);

create policy "Admins view own record"
  on admins for select
  using (auth.uid() = id);

create policy "Admins view all doctors"
  on doctors for select
  using (exists (select 1 from admins where admins.id = auth.uid()));

create policy "Admins view all staff"
  on staff for select
  using (exists (select 1 from admins where admins.id = auth.uid()));

create policy "Admins update staff targets"
  on staff for update
  using (exists (select 1 from admins where admins.id = auth.uid()))
  with check (exists (select 1 from admins where admins.id = auth.uid()));

create policy "Staff view all doctors"
  on doctors for select
  using (exists (select 1 from staff where staff.id = auth.uid()) or exists (select 1 from admins where admins.id = auth.uid()));

create policy "Staff manage all patients"
  on patients for all
  using (exists (select 1 from staff where staff.id = auth.uid()) or exists (select 1 from admins where admins.id = auth.uid()));

create policy "Admins view all patients"
  on patients for select
  using (exists (select 1 from admins where admins.id = auth.uid()));

create policy "Staff manage all follow-ups"
  on follow_ups for all
  using (exists (select 1 from staff where staff.id = auth.uid()) or exists (select 1 from admins where admins.id = auth.uid()));

create policy "Admins view all follow-ups"
  on follow_ups for select
  using (exists (select 1 from admins where admins.id = auth.uid()));
