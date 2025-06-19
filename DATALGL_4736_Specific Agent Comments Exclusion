---- FIRST TAKE 

with base as (
    SELECT 
        case_id,
       case_creation_date_utc,
        CASE 
            WHEN REGEXP_LIKE(LOWER(body), '.*duplicate case.*') THEN 'duplicate case'
            WHEN REGEXP_LIKE(LOWER(body), '.*dup case.*') THEN 'dup case'
            WHEN REGEXP_LIKE(LOWER(body), '.*duplicate of.*') THEN 'duplicate of'
            WHEN REGEXP_LIKE(LOWER(body), '.*see case #.*') THEN 'see case #'
            WHEN REGEXP_LIKE(LOWER(body), '.*related case.*') THEN 'related case'
            WHEN REGEXP_LIKE(LOWER(body), '.*already resolved.*') THEN 'already resolved'
        END as no_action_reason
    FROM cash_3pr_pii.public.cash_correspondence
    WHERE channel = 'FEED_ITEM'
    AND (

    
        REGEXP_LIKE(LOWER(body), '.*duplicate case.*')
        OR REGEXP_LIKE(LOWER(body), '.*dup case.*')
        OR REGEXP_LIKE(LOWER(body), '.*duplicate of.*')
        OR REGEXP_LIKE(LOWER(body), '.*see case #.*')
        OR REGEXP_LIKE(LOWER(body), '.*related case.*')
        OR REGEXP_LIKE(LOWER(body), '.*already resolved.*')
    )
    AND LOWER(body) NOT LIKE '%dispute%'
    AND LOWER(body) NOT LIKE '%unauthorized%'
    AND LOWER(body) NOT LIKE '%fraud%'
    AND LOWER(body) NOT LIKE '%scam%'
)

select 
    base.no_action_reason,
    pop.case_id,
    case_creation_date_utc

from base 
join app_cash_3pr.cfpb.pop_dead_end_combined_case_list pop
on base.case_id = pop.case_id
where no_action_reason is not null
--group by 1
order by 2 desc;


---SECOND TAKE - taking suggestion from chat GP on how to expand the variety of key words

with base as (
    SELECT 
        case_id,
       case_creation_date_utc,
       CASE 
    WHEN REGEXP_LIKE(LOWER(body), '.*duplicate (case|ticket|ref).*') THEN 'duplicate'
    WHEN REGEXP_LIKE(LOWER(body), '.*dupe.*') THEN 'dupe'
    WHEN REGEXP_LIKE(LOWER(body), '.*duplicated issue.*') THEN 'duplicated issue'
    WHEN REGEXP_LIKE(LOWER(body), '.*already resolved.*') THEN 'already resolved'
    WHEN REGEXP_LIKE(LOWER(body), '.*same as.*') THEN 'same as'
    WHEN REGEXP_LIKE(LOWER(body), '.*existing issue.*') THEN 'existing issue'
    WHEN REGEXP_LIKE(LOWER(body), '.*see (case|ticket).*') THEN 'see other case'
    WHEN REGEXP_LIKE(LOWER(body), '.*linked to.*') THEN 'linked to case'
    WHEN REGEXP_LIKE(LOWER(body), '.*refer to case.*') THEN 'refer to case'
    WHEN REGEXP_LIKE(LOWER(body), '.*merged (with|into).*') THEN 'merged'
    WHEN REGEXP_LIKE(LOWER(body), '.*relates to case.*') THEN 'related case'
    WHEN REGEXP_LIKE(LOWER(body), '.*case already exists.*') THEN 'case already exists'
END AS no_action_reason
    FROM cash_3pr_pii.public.cash_correspondence
    WHERE channel = 'FEED_ITEM'
    AND (

    
       REGEXP_LIKE(LOWER(body), '.*duplicate (case|ticket|ref).*')
OR REGEXP_LIKE(LOWER(body), '.*dupe.*')
OR REGEXP_LIKE(LOWER(body), '.*duplicated issue.*')
OR REGEXP_LIKE(LOWER(body), '.*already resolved.*')
OR REGEXP_LIKE(LOWER(body), '.*same as.*')
OR REGEXP_LIKE(LOWER(body), '.*existing issue.*')
OR REGEXP_LIKE(LOWER(body), '.*see (case|ticket).*')
OR REGEXP_LIKE(LOWER(body), '.*linked to.*')
OR REGEXP_LIKE(LOWER(body), '.*refer to case.*')
OR REGEXP_LIKE(LOWER(body), '.*merged (with|into).*')
OR REGEXP_LIKE(LOWER(body), '.*relates to case.*')
OR REGEXP_LIKE(LOWER(body), '.*case already exists.*')
    )
    AND LOWER(body) NOT LIKE '%dispute%'
    AND LOWER(body) NOT LIKE '%unauthorized%'
    AND LOWER(body) NOT LIKE '%fraud%'
    AND LOWER(body) NOT LIKE '%scam%'
)

select 
    base.no_action_reason,
    pop.case_id,
    case_creation_date_utc

from base 
join app_cash_3pr.cfpb.pop_dead_end_combined_case_list pop
on base.case_id = pop.case_id
where no_action_reason is not null
--group by 1
order by 2 desc;

