--- APPLICATION
select *
from cash_3pr_pii.afterpay.feb_de_applications
where split_part(application_id,'__',1) in (select order_token from app_cash_3pr.afterpay.test_attempt_exclusions)


---EOM

with base as
(
SELECT loan_details_loan_id loan_id
        , order_transaction_id order_id
FROM ap_raw_green.green.raw_c_e_order
WHERE payment_type = 'PCL' AND status = 'APPROVED'
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_transaction_id ORDER BY event_info_event_time DESC) = 1
)

select a.*, b.order_id
from app_cash_3pr.afterpay.feb_de_eom_monthly a
join base b
on a.loan_account_number = b.loan_id
where b.order_id in (select order_id from app_cash_3pr.afterpay.test_order_exclusions)


---- TRANSACTIONS

with base as
(
SELECT loan_details_loan_id loan_id
        , order_transaction_id order_id
FROM ap_raw_green.green.raw_c_e_order
WHERE payment_type = 'PCL' AND status = 'APPROVED'
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_transaction_id ORDER BY event_info_event_time DESC) = 1
)

select a.*, b.order_id
from app_cash_3pr.afterpay.feb_de_transactions a
join base b
on a.loan_account_number = b.loan_id
where b.order_id in (select order_id from app_cash_3pr.afterpay.test_order_exclusions)
