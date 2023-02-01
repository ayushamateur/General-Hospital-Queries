-- Find the patients who were born on or after 2000-01-01 and whose names start with M

WITH young_patients as(

         	Select * from patients
		where date_of_birth >= '2000-01-01'
		)

	select *
	from young_patients 
	where name like 'M%';


--Get number of surgeries by county for counties where we have more than 1500 patients

WITH top_counties as(
	select
	  county, count(*) as num_patients
	from patients
	group by county
	having count(*) > 1500
	),

	county_patients as(
	   select
	     p.master_patient_id, p.county
	   from patients p
	   Inner Join
	     top_counties t on
	   p.county = t.county
	   )

select p.county, count(s.surgery_id)
from surgical_encounters s
inner join county_patients p on
s.master_patient_id = p.master_patient_id
   group by p.county;



--Find surgeries that have a cost that is greater than average cost across all surgeries

WITH total_cost as(
	select surgery_id, SUM(resource_cost) as total_surgery_cost
	from surgical_costs
	group by surgery_id
	)
select * 
from total_cost
where total_surgery_cost > (
		select avg(total_surgery_cost)
		from total_cost
);


--Filter the patients table to look at the patients who've had surgeries

select * 
from patients
where master_patient_id IN(
	select distinct master_patient_id
	from surgical_encounters
	)
order by master_patient_id;


--Surgical procedures whose total profit is greater than the average cost for all diagnosis

select * 
from surgical_encounters
where total_profit > ALL(
	select avg(total_cost)
	from surgical_encounters
	group by diagnosis_description
);


--Average length of stay for all surgeries but compare that to the length of stay for individual surgeries

select 
surgery_id,
(surgical_discharge_date - surgical_admission_date)
as los,
avg(surgical_discharge_date - surgical_admission_date)
over() as avg_los
from surgical_encounters;


--recast above as CTE and then use it to look for over length of stay, or under length of stay for surgery

with surgical_los as(
	select surgery_id,
	(surgical_discharge_date - surgical_admission_date) as los,
	avg(surgical_discharge_date - surgical_admission_date)
	    over() as avg_los
from surgical_encounters
)

select * ,
(los - avg_los) as over_under
from surgical_los;


---Look at account balance ranking by diagnosis code or ICD

select account-id,
primary_icd, total_account_balance,
rank()
	over(partition by primary_icd order by total_account_balance)
	    as account_rank
from accounts;

---look at average total profit, and sum total cost of all surgeries by surgeon

select
	s.surgery_id, p.full_name, s.total_profit,
	avg(total_profit) over w as avg_total_profit,
	sum(total_cost) over w total_surgical_cost,
	s.total_cost
from surgical_encounters s
left outer join physicians p
on s.surgeon_id = p.id
window w as (partition by s.surgery_id);


---Rank of the surgical cost by surgeon and then the row number of profitability by surgeon and diagnosis

select
	s.surgery_id, p.full_name, s.total_cost,
	rank()
	  over(partition by surgeon_id order by total_cost asc)
	  as cost_rank,
	diagnosis_description,
	total_profit,
	row_number()
	  over(partition by surgeon_id, diagnosis_description order by total_profit desc)
	     as new_row_number
from surgical_encounters s
left outer join physicians p 
on s.surgery_id = p.id
order by s.surgeon_id, s.diagnosis_description;


---look at dates of the last and next visit by patient from the encounters table

select 
	patient_encounter_id,
	master_patient_id,
	patient_admission_datetime,
	patient_discharge_datetime,
	lag(patient_discharge_datetime) over w as
	             previous_discharge_date,
	lead(patient_admission_datetime) over w as 
	             next_admission_date
from encounters
window w as (partition by master_patient_id order by patient_admission_datetime);


---surgeries that were within 30 days of the previous surgery

WITH surgeries_lagged as(
	select
	surgery_id,
	master_patient_id,
	surgical_admission_date,
	surgical_discharge_date,
	lag(surgical_discharge_date)
	  over(partition by master_patient_id order by surgical_admission_date)
	  as previous_discharge_date
	from surgical_encounters
	)

select * ,
	(surgical_admission_date - previous_discharge_date)
	as dat_between_surgeries
	from surgeries_lagged
	where 
	(surgical_admission_date - previous_discharge_date) <= 30;


---select all surgeries that have the same length

select
	se1.surgery_id as surgery_id_1,
	(se1.surgical_discharge_date - se1.surgical_admission_date) as los_1,
	se2.surgery_id as surgery_id_2,
	(se2.surgical_discharge_date - se2.surgical_admission_date) as los_2
from surgical_encounters se1 
inner join 
surgical_encounters se2
on
(se1.surgical_discharge_date - se1.surgical_admission_date) = (se2.surgical_discharge_date - se2.surgical_admission_date);


---check which departments don't have hospital names, as that would be a data issue

select
	d.department_id,
	d.department_name
	from departments d
	full join hospital h
	  on d.hospital_id = h.hospital_id
	where 
	  h.hospital_id is NULL;


---get all the surgery id across the surgical encounters table and the surgical cost table

select surgery_id
from surgical_encounters
UNION
select surgery_id
from surgical_costs
order by surgery_id;


---find average profit by surgeon, admission type and diagnosis

select
	p.full_name,
	se.admission_type,
	se.diagnosis_description,
	count(*) as num_surgeries,
	avg(total_profit) as avg_total_profit
from surgical_encounters se
left outer join physicians p
on se.surgeon_id = p.id
group by grouping sets(
	(p.full_name),
	(se.admission_type, se.diagnosis_description),
	(p.full_name, se.admission_type),
	(p.full_name, se.diagnosis_description)
	);
