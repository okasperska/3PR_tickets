WITH 

ORDER_BASE AS

(
SELECT a.ID ORDER_ID,
a.CONSUMER_ID,
b.uuid,
a.FIRST_PAYMENT_UP_FRONT,
a.ORDER_DATE  ORDER_DATE,
a.CONSUMER_AMOUNT  ORDER_AMT
FROM AP_RAW_GREEN.green.F_ORDER a
join AP_RAW_GREEN.GREEN.d_consumer b
on a.consumer_id = b.id
where a.ORDER_DATE between '2025-06-10' and '2025-06-30'
 and a.ORDER_TRANSACTION_STATUS = 'Approved'
 and a.country_code = 'AU'
 )


,LIMITS AS (

SELECT lim.consumer_uuid,
'reg' as source,
max(lim.account_limit_amount) max_limit_amt,
from AP_CUR_RISKFEC_G.credit.cust_limit_daily_prod_au lim
where country_code = 'AU'
and to_date(lim.batch_dttm) between '2025-06-10' and '2025-06-30'
group by 1,2
)

---top up covers 76 consumers who created their accounts or transacted for a first time in a long time on 30 June - for some reason their limit is only recorded on 1 July which is a glitch with the table I have seen before
,TOP_UP AS (
SELECT lim.consumer_uuid,
'patch' as source,
max(lim.account_limit_amount) max_limit_amt
from AP_CUR_RISKFEC_G.credit.cust_limit_daily_prod_au lim
where country_code = 'AU'
and to_date(lim.batch_dttm) = '2025-07-01'
group by 1,2
)

-- effectively, the requirement narrows down only to customers who transacted in the period. For thos who did not the credit limit accesses is 0.
 , BASE AS (

 select distinct ob.uuid,
 case when lim.max_limit_amt is null then tu.max_limit_amt else lim.max_limit_amt end as max_limit_amt,
 case when lim.max_limit_amt is null then tu.source else lim.source end as source
 from order_base ob
 left join limits lim
 on ob.uuid = lim.consumer_uuid
 left join top_up tu
 on ob.uuid = tu.consumer_uuid
 )
 
 
,instalment_seq AS --to correctly calculate the principal for BNPl and Plus

(
SELECT
distinct a.id instalment_id,
a.gdp_region,
a.order_id,
a.original_due_date,
row_number() over ( partition by a.order_id,gdp_region order by a.original_due_date asc )  as instalment_seq_id
FROM ap_raw_green.green.f_instalment a
JOIN ORDER_BASE b
ON a.order_id = b.order_id
order by 2,3,1
)
            
,DISCOUNT AS
(
SELECT	A.ORDER_ID,
sum(A.amount_paid) DISCOUNT_AMT,
FROM AP_RAW_GREEN.green.F_INSTALMENT_EVENTS	A
JOIN ORDER_BASE B
ON 	A.ORDER_ID = B.order_id 
WHERE A.EVENT_TYPE in ('DISCOUNT')
GROUP BY 1
)

,downpayment AS 
(
SELECT	A.ORDER_ID,
sum(A.amount_paid)  DOWN_PAYMENT_AMT
FROM	AP_RAW_GREEN.green.F_INSTALMENT_EVENTS	A
JOIN	INSTALMENT_SEQ	B
ON 	(A.GDP_REGION = B.GDP_REGION and A.instalment_id = B.instalment_id)
JOIN	AP_RAW_GREEN.green.F_PAYMENT	C
ON 	(A.GDP_REGION = C.GDP_REGION and A.PAYMENT_ID = C.id AND A.event_date = C.completed_date)
JOIN order_base	E
on 	(A.ORDER_ID = E.order_id)
WHERE e.FIRST_PAYMENT_UP_FRONT= 1
and B.instalment_seq_id = 1
and C.payment_source IN ('Charge at ship', 'BUY_PROCESS', 'POS', 'Buy process')
and A.EVENT_TYPE in ('PAYMENT')
group by	1
)

,PRINCIPAL_STAGING AS
(
select 
a.uuid,
a.order_id,
a.order_amt,
case when b.DISCOUNT_AMT is null then 0 else b.DISCOUNT_AMT end DISCOUNT_AMT,
case when c.DOWN_PAYMENT_AMT is null then 0 else c.DOWN_PAYMENT_AMT end DOWN_PAYMENT_AMT
from ORDER_BASE a
LEFT JOIN DISCOUNT B
ON a.order_id = b.order_id
LEFT JOIN DOWNPAYMENT C
ON a.order_id = c.order_id
)

,PRINCIPAL AS --standard calc for principal
(
select 
uuid,
order_id,
(order_amt - discount_amt - down_payment_amt) PRINCIPAL_AMT
FROM PRINCIPAL_STAGING
)

,PRINCIPAL_AGG AS
(
select uuid,
sum(PRINCIPAL_AMT) SPEND_AMT
from PRINCIPAL
Group by 1
)

, FINAL_CALC AS -- this pass contains logic for comparing spend to max and credit limit and determines which metric is used for reporting for a particular customer 
(
select 
base.uuid,
base.source,
base.max_limit_amt,
prin.spend_amt,
case when prin.spend_amt < base.max_limit_amt then prin.spend_amt
     when prin.spend_amt >= base.max_limit_amt then base.max_limit_amt
     when prin.spend_amt is null then 0
     else 0 end                                                         as credit_accessed_amt
FROM base
JOIN PRINCIPAL_AGG prin
on base.uuid = prin.uuid
)

--litte QA pass
select sum(max_limit_amt) lim, sum(spend_amt) spend, lim-spend as diff, count (distinct uuid) customers_spent_over_limit from final_calc where spend_amt > max_limit_amt

Select 
sum(credit_accessed_amt) total_credit_accessed_amt,
sum(max_limit_amt) total_max_limit_amt,
sum(spend_amt) total_spend_amt
from FINAL_CALC



