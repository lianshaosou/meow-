-- Verifies push worker RPCs exist after staging migrations.

select
  to_regprocedure('public.claim_push_delivery_jobs(integer,text,integer)') is not null as has_claim_push_delivery_jobs,
  to_regprocedure('public.mark_push_delivery_job_sent(uuid,jsonb)') is not null as has_mark_push_delivery_job_sent,
  to_regprocedure('public.mark_push_delivery_job_failed(uuid,text,integer,integer,jsonb)') is not null as has_mark_push_delivery_job_failed,
  to_regprocedure('public.recover_stale_push_delivery_jobs(integer,integer)') is not null as has_recover_stale_push_delivery_jobs,
  to_regprocedure('public.deactivate_push_token_for_job(uuid,text)') is not null as has_deactivate_push_token_for_job;
