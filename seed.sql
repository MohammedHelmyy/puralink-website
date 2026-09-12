-- PuraLink account roles and sample patients
-- Run this in Supabase SQL Editor AFTER schema.sql.

-- Eric David and Kesha Adam are doctors. The UUIDs are looked up from
-- auth.users by email, avoiding manual UUID transcription errors.
insert into doctors (id, full_name, email)
select id, full_name, email
from (values
  ('Eric David', 'ericdavid@puralinklogin.com'),
  ('Kesha Adam', 'keshaadam@puralinklogin.com')
) as accounts(full_name, email)
join auth.users using (email)
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email;

-- Hussien Rizk, Mohammed Hesham, and Youssef Mohammed are staff.
insert into staff (id, full_name, email)
select id, full_name, email
from (values
  ('Hussien Rizk', 'hussienrizk@puralinklogin.com'),
  ('Mohammed Hesham', 'mohammedhesham@puralinklogin.com'),
  ('Youssef Mohammed', 'youssedmohammed@puralinklogin.com')
) as accounts(full_name, email)
join auth.users using (email)
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email;

-- Five sample patients assigned to Eric David.
insert into patients (doctor_id, patient_label, chronic_condition)
select doctors.id, patient_label, chronic_condition
from doctors
cross join (values
  ('Bella', 'Arthritis'),
  ('Max', 'Diabetes'),
  ('Charlie', 'Kidney disease'),
  ('Daisy', 'Allergies'),
  ('Milo', 'Heart condition')
) as sample_patients(patient_label, chronic_condition)
where doctors.email = 'ericdavid@puralinklogin.com'
  and not exists (
  select 1 from patients existing
  where existing.doctor_id = doctors.id
    and existing.patient_label = sample_patients.patient_label
);

-- Five sample patients assigned to Kesha Adam.
insert into patients (doctor_id, patient_label, chronic_condition)
select doctors.id, patient_label, chronic_condition
from doctors
cross join (values
  ('Luna', 'Asthma'),
  ('Rocky', 'Skin infection'),
  ('Coco', 'Liver disease'),
  ('Oliver', 'Joint pain'),
  ('Nala', 'Thyroid condition')
) as sample_patients(patient_label, chronic_condition)
where doctors.email = 'keshaadam@puralinklogin.com'
  and not exists (
  select 1 from patients existing
  where existing.doctor_id = doctors.id
    and existing.patient_label = sample_patients.patient_label
);
