---- CONSUMERS WHO ENTERED CREDIT CONTRACT BETWEEN 2024-09-02 AND 2025-03-31

CREATE OR REPLACE TABLE  PERSONAL_OKASPERSKA.public.nz_credit_contract AS

(

        (
        SELECT fo.consumer_id,
        dc.uuid consumer_uuid,
        'EXISTING' as consumer_type,
        dc.created_date acc_created_date,
        min(fo.order_date) entered_date,
        min(fo.order_datetime) entered_datetime
        from ap_raw_green.green.f_order fo
        join ap_raw_green.green.d_consumer dc
        on fo.consumer_id = dc.id
        where fo.country_code = 'NZ'
        and dc.created_date < '2024-09-02' -- consumers created before the regulation kicked in
        and fo.order_date between '2024-09-02' and '2025-03-31' -- next 3 conditions pick only consumers who had their first online transaction after the regulation kicked in
        and fo.order_transaction_status = 'Approved'
        group by 1,2,3,4
        )
        
        UNION
        (
        SELECT dc.id consumer_id,
        dc.uuid consumer_uuid,
        'NEW_ACCOUNT' as consumer_type,
        dc.created_date acc_created_date,
        dc.created_date entered_date,
        dc.created_datetime entered_datetime
        from ap_raw_green.green.d_consumer dc
        where dc.country_code = 'NZ'
        and dc.created_date between '2024-09-02' and '2025-03-31' -- consumers created after the regulation kicked in
        )

)




--1. Accounts created in NZ in reporting period

select --consumer_type,
count(consumer_UUID) consumers_entering_cc_cnt
from PERSONAL_OKASPERSKA.public.nz_credit_contract
where 1=1 --no filtering needed as the the referenced table only has the required population
group by 1
    


-- 2 & 4 Total Count and Value of all increases
with base as
(
select a.consumer_uuid, 
a.old_value, 
a.new_value, 
b.entered_date, 
(a.new_value - a.old_value ) as increase_amt
from ap_raw_green.green.raw_c_e_rulesenginekarma_decision_value_change a
join PERSONAL_OKASPERSKA.public.nz_credit_contract b
on a.consumer_uuid = b.consumer_uuid
where 1=1
and (convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000))) >= b.entered_datetime  --this will capture only the increases AFTER entering the cc
and to_date(convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000)))  <= '2025-03-31'
and a.old_value < a.new_value
and a.change_type = 'LIMIT'
)

select 
count(consumer_uuid) increase_cnt,
sum(increase_amt) increase_amt
from base

-- 2 & 4 Total Count and Value of all increases just for initial setups from points 2 and 4:

with base as
(
select a.consumer_uuid, 
a.old_value, 
a.new_value, 
b.entered_date, 
b.entered_datetime, 
b.consumer_type,
(a.new_value - a.old_value ) as increase_amt,
(convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000))) set_datetime,
to_date(convert_timezone('UTC', 'Pacific/Auckland', TO_TIMESTAMP_LTZ(a.TIMESTAMP / 1000))) set_date,
ROW_NUMBER () OVER(PARTITION BY  b.consumer_uuid ORDER BY  set_datetime asc) rnk --rnk=1 means it is the first record per consumer
from ap_raw_green.green.raw_c_e_rulesenginekarma_decision_value_change a
join PERSONAL_OKASPERSKA.public.nz_credit_contract b
on a.consumer_uuid = b.consumer_uuid
where 1=1
and set_date  <= '2025-03-31'
and a.old_value < a.new_value
and a.change_type = 'LIMIT'
)


select count(consumer_uuid) increase_cnt,
sum(increase_amt) increase_amt
from base
where 1=1
and rnk = 1 and old_value = 0 -- this filter will only bring the initial limit set ups
and ((set_date between '2024-09-02' and '2025-03-31' and consumer_type = 'NEW_ACCOUNT') OR (set_datetime >= entered_datetime and consumer_type = 'EXISTING')) -- to cater for preexisting consumers and rare scenario of initial limit setup prior to first online transaction in period


-- 3 Consumer's highest credit limit during the reporting period
--with base as 
(
select base.consumer_uuid,
max(lim.ACCOUNT_LIMIT_AMOUNT) max_acc_limit
from PERSONAL_OKASPERSKA.public.nz_credit_contract base
left join AP_CUR_RISKFEC_G.credit.cust_limit_daily_prod_au lim
on base.consumer_uuid = lim.consumer_uuid and lim.batch_dttm >= base.entered_datetime and to_date(lim.batch_dttm)<= '2025-03-31'
group by 1
)
--select sum(max_acc_limit) from base

--- 3 Day with the highest total limit
select to_date(lim.batch_dttm) Day,
sum(lim.ACCOUNT_LIMIT_AMOUNT) total_acc_limit
from PERSONAL_OKASPERSKA.public.nz_credit_contract base
left join AP_CUR_RISKFEC_G.credit.cust_limit_daily_prod_au lim
on base.consumer_uuid = lim.consumer_uuid and lim.batch_dttm >= base.entered_datetime and to_date(lim.batch_dttm)<= '2025-03-31'
group by 1
order by 2 desc
