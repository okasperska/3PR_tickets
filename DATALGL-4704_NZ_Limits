---- 1. CONSUMERS WHO ENTERED CREDIT CONTRACT BETWEEN 2024-09-02 AND 2025-03-31 and transacted in the period


       SELECT count (distinct fo.consumer_id) consumer_cnt
        from ap_raw_green.green.f_order fo
        join ap_raw_green.green.d_consumer dc
        on fo.consumer_id = dc.id
        where fo.country_code = 'NZ'
        and dc.created_date  between '2024-09-02' and '2025-03-31' -- consumers created before the regulation kicked in
        and fo.order_date between '2024-09-02' and '2025-03-31' -- next 3 conditions pick only consumers who had their first online transaction after the regulation kicked in
        and fo.order_transaction_status = 'Approved'
        




-- 2. Consumer's credit limit when entering the credit contract (at first order)



with BASE as

        (
        SELECT fo.consumer_id,
        dc.uuid consumer_uuid,
        dc.created_datetime,
        min(fo.order_date) entered_date,
        min(fo.order_datetime) entered_datetime
        from ap_raw_green.green.f_order fo
        join ap_raw_green.green.d_consumer dc
        on fo.consumer_id = dc.id
        where fo.country_code = 'NZ'
        --and dc.created_date  between '2024-09-02' and '2025-03-31' -- consumers created before the regulation kicked in
        and fo.order_date between '2024-09-02' and '2025-03-31' -- next 3 conditions pick only consumers who had their first online transaction after the regulation kicked in
        and fo.order_transaction_status = 'Approved'
        group by 1,2,3
        )
        
, dates1 as 
(
select base.consumer_uuid,
lim.ACCOUNT_LIMIT_AMOUNT acc_limit_at_contract_enter1,
from base
left join AP_CUR_RISKFEC_G.credit.cust_limit_daily_prod_au lim
on base.consumer_uuid = lim.consumer_uuid 
    and to_date(lim.batch_dttm) = base.entered_date 
    and to_date(lim.batch_dttm) <= '2025-03-31'
)

, dates2 as 
(
select base.consumer_uuid,
lim.ACCOUNT_LIMIT_AMOUNT acc_limit_at_contract_enter2,
from base
left join AP_CUR_RISKFEC_G.credit.cust_limit_daily_prod_au lim
on base.consumer_uuid = lim.consumer_uuid 
    and to_date(lim.batch_dttm) = base.entered_date + 1
    and to_date(lim.batch_dttm) <= '2025-04-30'
)

, final as 
(
select base.consumer_uuid,
dts1.acc_limit_at_contract_enter1,
dts2.acc_limit_at_contract_enter2,
case when acc_limit_at_contract_enter1 is null then acc_limit_at_contract_enter2 else acc_limit_at_contract_enter1 end as acc_limit_at_contract_enter,
base.created_datetime,
base.entered_datetime,
base.entered_date
from base
left join dates1 dts1
on base.consumer_uuid = dts1.consumer_uuid 
left join dates2 dts2
on base.consumer_uuid = dts2.consumer_uuid    
)

select sum(acc_limit_at_contract_enter) total_initial_limit from final



