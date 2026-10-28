create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG_PERM AS  
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG_PERM_VW AS
(
with price_perm as 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
b."Price_Change_Level"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG a
cross join (select s.value/100 as "Price_Change_Level"
from table(flatten(ARRAY_GENERATE_RANGE(100-10, 100+10+1, 1))) as s
) b
)

select 
* exclude (
"Monthly_Avg_Margin_Perm",
"Monthly_Index_Max_Avg_Margin_Perm",
"Monthly_Index_Min_Avg_Margin_Perm"
)
,"Monthly_Avg_Margin_Perm" as "Monthly_Avg_Margin_I",
"Monthly_Index_Max_Avg_Margin_Perm" as "Monthly_Index_Max_Avg_Margin_I",
"Monthly_Index_Min_Avg_Margin_Perm" as "Monthly_Index_Min_Avg_Margin_I"
,current_date() as "Insertion_Date"
from 
(
select distinct 
a.* exclude(
"Monthly_Avg_Margin_I",
"Monthly_Index_Max_Avg_Margin_I",
"Monthly_Index_Min_Avg_Margin_I"
,"Insertion_Date"
)
,c."Monthly_Avg_Cost_Price_I",
c."Monthly_Avg_Nett_Price_I",
c."P12M_Max_Avg_Margin_I",
c."P12M_Min_Avg_Margin_I",
b."Price_Change_Level",
round(c."Monthly_Avg_Nett_Price_I"*b."Price_Change_Level",2) as "Monthly_Avg_Nett_Price_Perm",
round(100*("Monthly_Avg_Nett_Price_Perm"-c."Monthly_Avg_Cost_Price_I")/c."Monthly_Avg_Cost_Price_I",2) "Monthly_Avg_Margin_Perm",
"Monthly_Avg_Margin_Perm"-c."P12M_Max_Avg_Margin_I" as "Monthly_Diff_Max_Avg_Margin_Perm",
case when "Monthly_Avg_Margin_Perm"=0 and c."P12M_Max_Avg_Margin_I"=0 then 0
      when "Monthly_Avg_Margin_Perm">0 and c."P12M_Max_Avg_Margin_I"<=0 then 10000
      when "Monthly_Avg_Margin_Perm"<0 and c."P12M_Max_Avg_Margin_I"=0 then -10000
      when "Monthly_Avg_Margin_Perm"<=0 and c."P12M_Max_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Max_Avg_Margin_Perm"/c."P12M_Max_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Max_Avg_Margin_Perm"/c."P12M_Max_Avg_Margin_I",1) end as "Monthly_Index_Max_Avg_Margin_Perm",
"Monthly_Avg_Margin_Perm"-c."P12M_Min_Avg_Margin_I" as "Monthly_Diff_Min_Avg_Margin_Perm",
case when "Monthly_Avg_Margin_Perm"=0 and c."P12M_Min_Avg_Margin_I"=0 then 0
      when "Monthly_Avg_Margin_Perm">0 and c."P12M_Min_Avg_Margin_I"<=0 then 10000
      when "Monthly_Avg_Margin_Perm"<0 and c."P12M_Min_Avg_Margin_I"=0 then -10000
      when "Monthly_Avg_Margin_Perm"<=0 and c."P12M_Min_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Min_Avg_Margin_Perm"/c."P12M_Min_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Min_Avg_Margin_Perm"/c."P12M_Min_Avg_Margin_I",1) end as "Monthly_Index_Min_Avg_Margin_Perm"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG a
inner join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_SCORE_KIA_FEAT c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
and c."Monthly_Avg_Cost_Price_I" is not null 
and c."Monthly_Avg_Nett_Price_I" is not null 
--and c."Monthly_Avg_Nett_Price_I">c."Monthly_Avg_Cost_Price_I"
inner join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT d
on a."Store_Code"=d."Store_Code"
and a."Product_Code"=d."Product_Code"
and a."Month_Start_Date"=d."Month_Start_Date"
and d."Wholesale_Promo_Flag"=0
left join price_perm b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
--where "Monthly_Avg_Nett_Price_Perm" is not null
)
ORDER BY "Store_Code","Product_Code"
,"Month_Start_Date"
,"Price_Change_Level"
)
;