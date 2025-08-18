--1. Accounts created in NZ in reporting period

select count(dc.id) consumer_cnt,
from ap_raw_green.green.d_consumer dc
where dc.country_code in ('NZ') and created_date between '2024-04-01' and '2025-03-31'

-- just active accounts
SELECT
        count(distinct consumer_uuid) 
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end
    WHERE acc_closed_flag = 'N'
    AND acc_wo_flag = 'N'
    AND self_exclusion_flag = 'N'
    AND acc_created_date between '2024-04-01' and '2025-03-31'
    and country_code = 'NZ'
    

--2. Limit increases

select count(a.consumer_uuid)
from ap_raw_green.green.raw_c_e_rulesenginekarma_decision_value_change a
join ap_raw_green.green.d_consumer b
on a.consumer_uuid = b.uuid
where 1=1
and b.country_code in ('NZ')
and to_date(convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000)))  between '2024-04-01' and '2025-03-31'
and a.old_value < a.new_value
and a.change_type = 'LIMIT'

--3. Total Limit (PERSONAL_OKASPERSKA.public.anz_limits_end created as per DATALGL-4292)
SELECT
        country_code,
        count(distinct consumer_uuid) as account_cnt_period_end,
        sum(acc_limit) as total_limit_period_end
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end
    WHERE acc_closed_flag = 'N'
    AND acc_wo_flag = 'N'
    AND self_exclusion_flag = 'N'
    AND acc_created_date <= '2025-03-31'
    and country_code = 'NZ'
    GROUP BY 1

    -- insluding written off, closed and self excluded

    SELECT
        country_code,
        count(distinct consumer_uuid) as account_cnt_period_end,
        sum(acc_limit) as total_limit_period_end
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end

--4 Total Value of all increases
with base as
(
select a.consumer_uuid, a.old_value, a.new_value, b.created_date acc_created_date, (a.new_value - a.old_value ) as increase_amt
from ap_raw_green.green.raw_c_e_rulesenginekarma_decision_value_change a
join ap_raw_green.green.d_consumer b
on a.consumer_uuid = b.uuid
where 1=1
and b.country_code in ('NZ')
and to_date(convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000)))  between '2024-04-01' and '2025-03-31'
and a.old_value < a.new_value
and a.change_type = 'LIMIT'

)

select sum(increase_amt)from base
    WHERE acc_created_date <= '2025-03-31'

----REMEDIATION: we need to exclude initial setups from points 2 and 4:
with base as
(
select consumer_uuid,
(a.new_value - a.old_value ) as increase_amt,
(convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000))) set_datetime,
to_date(convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000))) set_date,
a.old_value,
a.new_value,
ROW_NUMBER () OVER(PARTITION BY  consumer_uuid ORDER BY  set_datetime desc) rnk --rnk=1 means it is the first record per consumer
from ap_raw_green.green.raw_c_e_rulesenginekarma_decision_value_change a
join ap_raw_green.green.d_consumer b
on a.consumer_uuid = b.uuid
where 1=1
and b.country_code in ('NZ')
and set_date  <= '2025-03-31'
and a.old_value < a.new_value
and a.change_type = 'LIMIT'
)

select count(consumer_uuid) increase_cnt,
sum(increase_amt) increase_amt
from base
where set_date between '2024-04-01' and '2025-03-31' -- applying the period filter in the final pass
and rnk = 1 and old_value = 0 -- this filter will only bring the initial limit set ups
