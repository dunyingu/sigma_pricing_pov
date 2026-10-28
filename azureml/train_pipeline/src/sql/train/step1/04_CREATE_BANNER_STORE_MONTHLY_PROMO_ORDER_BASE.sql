CREATE OR REPLACE TABLE BANNER_STORE_MONTHLY_PROMO_ORDER_BASE AS 
--CREATE OR REPLACE VIEW BANNER_STORE_MONTHLY_PROMO_ORDER_BASE_VW AS
(
with promo as (
SELECT DISTINCT 
a."Promotion_Brief_Detail_Key",
a."Blueprint_Banner_Key",
b."Banner_Abbreviation",
upper(b."Banner_Name") "Banner_Name",
CASE WHEN "Banner_Abbreviation"='WL' THEN 'WLF'
	 WHEN "Banner_Abbreviation"='PS' THEN 'PSP'
	 WHEN "Banner_Abbreviation"='CK' THEN 'CHK'
	 WHEN upper("Banner_Abbreviation") IN ('UKN','UNKNOWN','N/A','NA','BLANK','NOT APPLICABLE') THEN null
	 ELSE "Banner_Abbreviation" END AS "Mapped_Banner_Code",
a."Product_Key",
right(c."Product_Code",8) "Product_Code",
a."Supplier_Key",
date(a."Buy_Period_Start_Date_Key",'yyyymmdd') as "Wholesale_Promo_Start_Date",
date(a."Buy_Period_End_Date_Key",'yyyymmdd') as "Wholesale_Promo_End_Date",
date_trunc('month',"Wholesale_Promo_Start_Date") as "Wholesale_Promo_Start_Month",
date_trunc('month',"Wholesale_Promo_End_Date") as "Wholesale_Promo_End_Month",
date(a."Buy_Period_End_Date_Key",'yyyymmdd')-date(a."Buy_Period_Start_Date_Key",'yyyymmdd')+1 "Wholesale_Promo_Duration_Days",
a."Promotion_Minimum_Buy_Qty" AS "Promo_Minimum_Buy_Qty_Per_Order",
a."Promotion_Discount_Percentage" AS "Wholesale_Promo_Discount_Percentage",
date(a."Promo_Start_Date_Key",'yyyymmdd') as "Retail_Promo_Start_Date",
date(a."Promo_End_Date_Key",'yyyymmdd') as "Retail_Promo_End_Date",
date_trunc('month',"Retail_Promo_Start_Date") as "Retail_Promo_Start_Month",
date_trunc('month',"Retail_Promo_End_Date") as "Retail_Promo_End_Month",
date(a."Promo_End_Date_Key",'yyyymmdd')-date(a."Promo_Start_Date_Key",'yyyymmdd')+1 "Retail_Promo_Duration_Days",
a."Saving_Percentage" "Retail_Promo_Discount_Percentage"
FROM "EDP_PROD"."PRES"."Fact_Blueprint_Promotion" a
JOIN "EDP_PROD"."PRES"."Dim_Blueprint_Banner" b
ON a."Blueprint_Banner_Key" = b."Blueprint_Banner_Key"
JOIN edp_prod.pres."Dim_Product" c
ON a."Product_Key"=c."Product_Key"
and c."Product_Key">0
where a."Promotion_Brief_Detail_Key"!=-1
)
,
hist_dmnd_banner as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
--case when b."Demand_Group_Code" is not null then b."Demand_Group_Code"
	 --when b."Demand_Group_Code" is null and upper(c."Demand_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then  c."Demand_Group_Code"
	 --else null end as "Demand_Group_Code",
case when b."Banner_Group_Code" is not null then b."Banner_Group_Code"
	 when b."Banner_Group_Code" is null and upper(c."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then  c."Banner_Group_Code"
	 else null end as "Banner_Group_Code"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
left join 
(
select distinct
a."Month_Start_Date",
a."Store_Code",
--case when upper(b."Demand_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then b."Demand_Group_Code"
	 --else null end as "Demand_Group_Code",
case when upper(b."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then b."Banner_Group_Code"
	 else null end as "Banner_Group_Code",
a."Month_Start_Date" - b."Effective_Start_Date" as "Effective_Days"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
left join core.DIM_CUSTOMER_STORE_HIST b
ON a."Store_Code"=b."Store_Code" 
and a."Month_Start_Date">=b."Effective_Start_Date"
and a."Month_Start_Date"<b."Effective_End_Date"
QUALIFY Row_Number() OVER (PARTITION BY 
a."Month_Start_Date",
a."Store_Code"
----"Demand_Group_Code",
--"Banner_Group_Code"
ORDER BY "Effective_Days")=1
) b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
left join edp_prod.pres."Dim_Customer_Retail_Store" h
ON a."Store_Code" = h."Store_Code"
left join edp_prod.pres."Dim_Customer" c
on h."Site_Link_Code"=c."Site_Link_Code"
and c."Distribution_Channel_Name"='WHOLESALE'
)
,
wholesale_promo as (
select distinct 
a."Month_Start_Date",
dateadd('month',1,a."Month_Start_Date")-1 as "Month_End_Date",
--b."Demand_Group_Code",
b."Banner_Group_Code",
a."Product_Code",
e."Promotion_Brief_Detail_Key",
e."Wholesale_Promo_Start_Date",
e."Wholesale_Promo_End_Date",
e."Wholesale_Promo_Start_Month",
e."Wholesale_Promo_End_Month",
e."Wholesale_Promo_Duration_Days",
e."Promo_Minimum_Buy_Qty_Per_Order",
case when a."Month_Start_Date"=e."Wholesale_Promo_Start_Month" then e."Wholesale_Promo_Start_Date"
     when a."Month_Start_Date">e."Wholesale_Promo_Start_Month" then a."Month_Start_Date"
     end as "Monthly_Wholesale_Promo_Start_Date",
case when a."Month_Start_Date"=e."Wholesale_Promo_End_Month" then e."Wholesale_Promo_End_Date"
     when a."Month_Start_Date"<e."Wholesale_Promo_End_Month" then "Month_End_Date"
     end as "Monthly_Wholesale_Promo_End_Date",
"Monthly_Wholesale_Promo_End_Date"-"Monthly_Wholesale_Promo_Start_Date"+1 as "Monthly_Wholesale_Promotion_Days",
e."Wholesale_Promo_Duration_Days"-("Monthly_Wholesale_Promo_End_Date"-e."Wholesale_Promo_Start_Date"+1) as "Wholesale_Promo_Remaining_Days",
round(100*"Wholesale_Promo_Remaining_Days"/e."Wholesale_Promo_Duration_Days",2) as "Wholesale_Promo_Remaining_Days_Portion",
e."Wholesale_Promo_Discount_Percentage"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
--join edp_prod.pres."Dim_Customer_Retail_Store" h
--ON a."Store_Code" = h."Store_Code"
--join edp_prod.pres."Dim_Customer" b
--on h."Site_Link_Code"=b."Site_Link_Code"
--and b."Distribution_Channel_Name"='WHOLESALE'
left join hist_dmnd_banner b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
--and b."Banner_Group_Code" is not null
--and upper(b."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK')
left join promo e
on b."Banner_Group_Code"=e."Mapped_Banner_Code"
and a."Product_Code"=e."Product_Code"
and (a."Month_Start_Date" between e."Wholesale_Promo_Start_Month" and e."Wholesale_Promo_End_Month")
)
,
retail_promo as (
select distinct 
a."Month_Start_Date",
dateadd('month',1,a."Month_Start_Date")-1 as "Month_End_Date",
--a."Demand_Group_Code",
b."Banner_Group_Code",
a."Product_Code",
e."Promotion_Brief_Detail_Key",
e."Retail_Promo_Start_Date",
e."Retail_Promo_End_Date",
e."Retail_Promo_Start_Month",
e."Retail_Promo_End_Month",
e."Retail_Promo_Duration_Days",
case when a."Month_Start_Date"=e."Retail_Promo_Start_Month" then e."Retail_Promo_Start_Date"
     when a."Month_Start_Date">e."Retail_Promo_Start_Month" then a."Month_Start_Date"
     end as "Monthly_Retail_Promo_Start_Date",
case when a."Month_Start_Date"=e."Retail_Promo_End_Month" then e."Retail_Promo_End_Date"
     when a."Month_Start_Date"<e."Retail_Promo_End_Month" then "Month_End_Date"
     end as "Monthly_Retail_Promo_End_Date",
"Monthly_Retail_Promo_End_Date"-"Monthly_Retail_Promo_Start_Date"+1 as "Monthly_Retail_Promotion_Days",
e."Retail_Promo_Duration_Days"-("Monthly_Retail_Promo_End_Date"-e."Retail_Promo_Start_Date"+1) as "Retail_Promo_Remaining_Days",
round(100*"Retail_Promo_Remaining_Days"/e."Retail_Promo_Duration_Days",2) as "Retail_Promo_Remaining_Days_Portion",
e."Retail_Promo_Discount_Percentage"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
--join edp_prod.pres."Dim_Customer_Retail_Store" h
--ON a."Store_Code" = h."Store_Code"
--join edp_prod.pres."Dim_Customer" b
--on h."Site_Link_Code"=b."Site_Link_Code"
--and b."Distribution_Channel_Name"='WHOLESALE'
left join hist_dmnd_banner b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
--and b."Banner_Group_Code" is not null
--and upper(b."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK')
left join promo e
on b."Banner_Group_Code"=e."Mapped_Banner_Code"
and a."Product_Code"=e."Product_Code"
and (a."Month_Start_Date" between e."Retail_Promo_Start_Month" and e."Retail_Promo_End_Month")
)


select 
"Month_Start_Date",
--"Banner_Group_Code",
"Store_Code",
"Product_Code",
current_date() as "Insertion_Date",
count(distinct "Promotion_Brief_Detail_Key") "Promo_Cnt",
--case when "Promo_Cnt">=1 then 1
  --  else 0 end as "Promo_Flag",
min("Wholesale_Promo_Start_Date") "Wholesale_Promo_Start_Date_Min",
--max("Wholesale_Promo_Start_Date") "Wholesale_Promo_Start_Date_Max",
--min("Wholesale_Promo_End_Date") "Wholesale_Promo_End_Date_Min",
max("Wholesale_Promo_End_Date") "Wholesale_Promo_End_Date_Max",
--min("Wholesale_Promo_Duration_Days") "Wholesale_Promo_Duration_Days_Min",
--max("Wholesale_Promo_Duration_Days") "Wholesale_Promo_Duration_Days_Max",
--median("Wholesale_Promo_Duration_Days") "Wholesale_Promo_Duration_Days_Med",
--avg(c."Wholesale_Promo_Duration_Days") "Wholesale_Promo_Duration_Days_Avg",
min("Monthly_Wholesale_Promo_Start_Date") "Monthly_Wholesale_Promo_Start_Date_Min",
--max("Monthly_Wholesale_Promo_Start_Date") "Monthly_Wholesale_Promo_Start_Date_Max",
--min("Monthly_Wholesale_Promo_End_Date") "Monthly_Wholesale_Promo_End_Date_Min",
max("Monthly_Wholesale_Promo_End_Date") "Monthly_Wholesale_Promo_End_Date_Max",
--min("Monthly_Wholesale_Promotion_Days") "Monthly_Wholesale_Promotion_Days_Min",
--max("Monthly_Wholesale_Promotion_Days") "Monthly_Wholesale_Promotion_Days_Max",
--median("Monthly_Wholesale_Promotion_Days") "Monthly_Wholesale_Promotion_Days_Med",
--avg("Monthly_Wholesale_Promotion_Days") "Monthly_Wholesale_Promotion_Days_Avg",
--min("Wholesale_Promo_Remaining_Days") "Wholesale_Promo_Remaining_Days_Min",
--max("Wholesale_Promo_Remaining_Days") "Wholesale_Promo_Remaining_Days_Max",
--median("Wholesale_Promo_Remaining_Days") "Wholesale_Promo_Remaining_Days_Med",
--avg("Wholesale_Promo_Remaining_Days") "Wholesale_Promo_Remaining_Days_Avg",
--min("Wholesale_Promo_Remaining_Days_Portion") "Wholesale_Promo_Remaining_Days_Portion_Min",
--max("Wholesale_Promo_Remaining_Days_Portion") "Wholesale_Promo_Remaining_Days_Portion_Max",
--median("Wholesale_Promo_Remaining_Days_Portion") "Wholesale_Promo_Remaining_Days_Portion_Med",
--avg("Wholesale_Promo_Remaining_Days_Portion") "Wholesale_Promo_Remaining_Days_Portion_Avg",
--min("Wholesale_Promo_Discount_Percentage") "Wholesale_Promo_Discount_Percentage_Min",
--max("Wholesale_Promo_Discount_Percentage") "Wholesale_Promo_Discount_Percentage_Max",
--median("Wholesale_Promo_Discount_Percentage") "Wholesale_Promo_Discount_Percentage_Med",
avg("Wholesale_Promo_Discount_Percentage") "Wholesale_Promo_Discount_Percentage_Avg",
min("Promo_Minimum_Buy_Qty_Per_Order") "Promo_Minimum_Buy_Qty_Per_Order_Min",
--max("Promo_Minimum_Buy_Qty_Per_Order") "Promo_Minimum_Buy_Qty_Per_Order_Max",
--median("Promo_Minimum_Buy_Qty_Per_Order") "Promo_Minimum_Buy_Qty_Per_Order_Med",
--avg("Promo_Minimum_Buy_Qty_Per_Order") "Promo_Minimum_Buy_Qty_Per_Order_Avg",
min("Retail_Promo_Start_Date") "Retail_Promo_Start_Date_Min",
--max("Retail_Promo_Start_Date") "Retail_Promo_Start_Date_Max",
--min("Retail_Promo_End_Date") "Retail_Promo_End_Date_Min",
max("Retail_Promo_End_Date") "Retail_Promo_End_Date_Max",
--min("Retail_Promo_Duration_Days") "Retail_Promo_Duration_Days_Min",
--max("Retail_Promo_Duration_Days") "Retail_Promo_Duration_Days_Max",
--median("Retail_Promo_Duration_Days") "Retail_Promo_Duration_Days_Med",
--avg("Retail_Promo_Duration_Days") "Retail_Promo_Duration_Days_Avg",
min("Monthly_Retail_Promo_Start_Date") "Monthly_Retail_Promo_Start_Date_Min",
--max("Monthly_Retail_Promo_Start_Date") "Monthly_Retail_Promo_Start_Date_Max",
--min("Monthly_Retail_Promo_End_Date") "Monthly_Retail_Promo_End_Date_Min",
max("Monthly_Retail_Promo_End_Date") "Monthly_Retail_Promo_End_Date_Max",
--min("Monthly_Retail_Promotion_Days") "Monthly_Retail_Promotion_Days_Min",
--max("Monthly_Retail_Promotion_Days") "Monthly_Retail_Promotion_Days_Max",
--median("Monthly_Retail_Promotion_Days") "Monthly_Retail_Promotion_Days_Med",
--avg("Monthly_Retail_Promotion_Days") "Monthly_Retail_Promotion_Days_Avg",
--min("Retail_Promo_Remaining_Days") "Retail_Promo_Remaining_Days_Min",
--max("Retail_Promo_Remaining_Days") "Retail_Promo_Remaining_Days_Max",
--median("Retail_Promo_Remaining_Days") "Retail_Promo_Remaining_Days_Med",
--avg("Retail_Promo_Remaining_Days") "Retail_Promo_Remaining_Days_Avg",
--min("Retail_Promo_Remaining_Days_Portion") "Retail_Promo_Remaining_Days_Portion_Min",
--max("Retail_Promo_Remaining_Days_Portion") "Retail_Promo_Remaining_Days_Portion_Max",
--median("Retail_Promo_Remaining_Days_Portion") "Retail_Promo_Remaining_Days_Portion_Med",
--avg("Retail_Promo_Remaining_Days_Portion") "Retail_Promo_Remaining_Days_Portion_Avg",
--min("Retail_Promo_Discount_Percentage") "Retail_Promo_Discount_Percentage_Min",
--max("Retail_Promo_Discount_Percentage") "Retail_Promo_Discount_Percentage_Max",
--median("Retail_Promo_Discount_Percentage") "Retail_Promo_Discount_Percentage_Med",
avg("Retail_Promo_Discount_Percentage") "Retail_Promo_Discount_Percentage_Avg"
from 
(
select distinct e."Store_Code",
a.*,
b."Retail_Promo_Start_Date",
b."Retail_Promo_End_Date",
b."Retail_Promo_Start_Month",
b."Retail_Promo_End_Month",
b."Retail_Promo_Duration_Days",
b."Monthly_Retail_Promo_Start_Date",
b."Monthly_Retail_Promo_End_Date",
b."Monthly_Retail_Promotion_Days",
b."Retail_Promo_Remaining_Days",
b."Retail_Promo_Remaining_Days_Portion",
b."Retail_Promo_Discount_Percentage"
from wholesale_promo a
left join retail_promo b
on a."Month_Start_Date"=b."Month_Start_Date"
--and a."Demand_Group_Code"=b."Demand_Group_Code"
and a."Banner_Group_Code"=b."Banner_Group_Code"
and a."Product_Code"=b."Product_Code"
and a."Promotion_Brief_Detail_Key"=b."Promotion_Brief_Detail_Key"
--join "EDP_PROD"."PRES"."Dim_Customer" d
--on --c."Demand_Group_Code"=d."Demand_Group_Code"
--a."Banner_Group_Code"=d."Banner_Group_Code"
--and d."Distribution_Channel_Name"='WHOLESALE'
--join edp_prod.pres."Dim_Customer_Retail_Store" h
--ON d."Site_Link_Code" = h."Site_Link_Code"
--join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE e
--on h."Store_Code"=e."Store_Code"
join hist_dmnd_banner e
on a."Month_Start_Date"=e."Month_Start_Date"
--and a."Demand_Group_Code"=e."Demand_Group_Code"
and a."Banner_Group_Code"=e."Banner_Group_Code"
) 
group by all
)
;