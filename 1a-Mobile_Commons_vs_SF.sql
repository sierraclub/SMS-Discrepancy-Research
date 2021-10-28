--Salesforce
CREATE TEMPORARY TABLE sfstep1 AS
SELECT 
  REPLACE(REPLACE(REPLACE(REPLACE(phone, '(', ''),')',''), ' ',''),'-','') AS phone, 
  mobile_commons_outreach_preference__c, 
  lastmodifieddate
FROM sc_analytics.salescloud_contact_w_source
WHERE phone IS NOT NULL;

CREATE TEMPORARY TABLE sfstep2 AS
SELECT 
  phone, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In' THEN '1' ELSE '0' END AS mcop_OptIn, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In Failed' THEN '1' ELSE '0' END AS mcop_OptIn_Failed, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-In Requested' THEN '1' ELSE '0' END AS mcop_OptIn_Requested, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-Out' THEN '1' ELSE '0' END AS mcop_OptOut, 
  CASE WHEN mobile_commons_outreach_preference__c = 'Opt-Out Requested' THEN '1' ELSE '0' END AS mcop_OptOut_Requested,
  CASE WHEN mobile_commons_outreach_preference__c IS NULL THEN '1' ELSE '0' END AS mcop_null
FROM sfstep1
;

CREATE TEMPORARY TABLE sfstep3 AS
SELECT 
  phone, 
  sum(mcop_OptIn) AS mcop_optin, 
  (sum(mcop_OptIn_Failed) +
  sum(mcop_OptIn_Requested) +
  sum(mcop_OptOut) +
  sum(mcop_OptOut_Requested) +
  sum(mcop_null)) AS mcop_optout,
  count(*) AS total_instances
FROM sfstep2
GROUP BY 1;

CREATE TEMPORARY TABLE sfstep4 AS
SELECT 
  phone, 
  CASE WHEN mcop_optout > 0 THEN 'Opt-Out' ELSE 'Opt-In' END AS sf_sms_status
FROM sfstep3;

--Mobile Commons
CREATE TEMPORARY TABLE mcstep1 AS 
SELECT
  right(phone_number, 10) as phone, 
    opted_out_at
FROM sc_mobilecommons_staging.profiles
WHERE phone_number IS NOT NULL;

CREATE TEMPORARY TABLE mcstep2 AS 
SELECT 
    phone, 
    CASE WHEN opted_out_at IS NOT NULL THEN '1' ELSE '0' END AS opted_out,
    CASE WHEN opted_out_at IS NULL THEN '1' ELSE '0' END AS opted_in
FROM mcstep1;

CREATE TEMPORARY TABLE mcstep3 AS 
SELECT 
  phone, 
  sum(opted_out) AS opted_out, 
  sum(opted_in) AS opted_in,
  count(*) AS total_instances
FROM mcstep2
GROUP BY 1
ORDER BY 4 DESC;

CREATE TEMPORARY TABLE mcstep4 AS 
SELECT 
  phone, 
  CASE WHEN opted_out > 0 THEN 'Opt-Out' ELSE 'Opt-In' END AS mc_sms_status
FROM mcstep3;

-- JOIN
SELECT a.phone, a.sf_sms_status, b.mc_sms_status
FROM sfstep4 a
LEFT JOIN mcstep4 b
ON a.phone = b.phone
WHERE a.sf_sms_status <> b.mc_sms_status;