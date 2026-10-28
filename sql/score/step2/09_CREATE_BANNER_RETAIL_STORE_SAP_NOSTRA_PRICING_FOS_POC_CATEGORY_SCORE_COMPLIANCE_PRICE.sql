create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_CATEGORY_SCORE_COMPLIANCE_PRICE AS  
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_CATEGORY_SCORE_COMPLIANCE_PRICE_VW AS
(
with past_order as (
select distinct 
a."Store_Code",
c."Store_Name",
--a."Product_Code"
concat(c."Level_3_Name",' ',c."Level_4_Name") as "Category",
a."Current_Month_Start_Date",
sum(a."Monthly_Store_Product_Sigma_Order_Quantity") "Sigma_P12M_Total_Order_Quantity",
sum(a."Monthly_Store_Product_NonSigma_Order_Quantity") "NonSigma_P12M_Total_Order_Quantity"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_P12M_ORDER a
left join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM c
on a."Product_Code"=c."Product_Code"
and a."Store_Code"=c."Store_Code"
group by all
)
,
compliance as (
select distinct
"Current_Month_Start_Date" as "Month_Start_Date",
"Store_Code",
"Store_Name",
"Category",
"Sigma_P12M_Total_Order_Quantity"+"NonSigma_P12M_Total_Order_Quantity" as "P12M_Total_Order_Quantity",
case when "P12M_Total_Order_Quantity">0 then round(100*"Sigma_P12M_Total_Order_Quantity"/"P12M_Total_Order_Quantity",2) 
     else null end as "P12M_Category_Compliance"
from past_order
)
,
price_sensitivity as (
select 
"Month_Start_Date",
"Store_Code",
"Store_Name",
"Category",
sum("Monthly_Store_Product_Order_Quantity_Pred") as "Monthly_Store_Category_Order_Quantity_Pred",
sum("Monthly_Store_Product_Order_Quantity_Change") as "Monthly_Store_Category_Order_Quantity_Change",
"Monthly_Store_Category_Order_Quantity_Change"/"Monthly_Store_Category_Order_Quantity_Pred" as "Category_Price_Qty_Percent_Change"
from 
(
select distinct
a."Month_Start_Date",
a."Store_Code",
c."Store_Name",
a."Product_Code",
concat(c."Level_3_Name",' ',c."Level_4_Name") as "Category",
a."Price_Qty_Percent_Change",
b."Price_Change_Level",
b."Monthly_Store_Product_Order_Quantity_Pred",
round(b."Monthly_Store_Product_Order_Quantity_Pred"*a."Price_Qty_Percent_Change",0) as "Monthly_Store_Product_Order_Quantity_Change"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
left join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and b."Price_Change_Level"=1.0
join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
)
group by 1,2,3,4
)
,
compliance_percent_rank as (
select distinct 
"Month_Start_Date",
"Store_Code",
"Store_Name",
"Category",
"P12M_Category_Compliance",
PERCENT_RANK() OVER (PARTITION BY "Category","Month_Start_Date" ORDER BY ifnull("P12M_Category_Compliance",0)) AS "P12M_Store_Category_Compliance_Percent_Rank"
from compliance
--where "Month_Start_Date">=date('2023-09-01')
)
,
compliance_percent_rank_med as (
select
"Month_Start_Date",
"Category",
median("P12M_Category_Compliance") as "P12M_Store_Category_Compliance_Med",
median("P12M_Store_Category_Compliance_Percent_Rank") as "P12M_Store_Category_Compliance_Percent_Rank_Med"
from 
(
select distinct 
"Month_Start_Date",
"Category",
"P12M_Category_Compliance",
"P12M_Store_Category_Compliance_Percent_Rank"
from compliance_percent_rank
order by "Month_Start_Date","Category","P12M_Category_Compliance"
)
group by all
)
,
price_sensitivity_percent_rank as (
select distinct 
"Month_Start_Date",
"Store_Code",
"Store_Name",
"Category",
"Category_Price_Qty_Percent_Change",
PERCENT_RANK() OVER (PARTITION BY "Category","Month_Start_Date" ORDER BY ifnull("Category_Price_Qty_Percent_Change",0)) AS "Category_Price_Qty_Percent_Change_Percent_Rank"
from price_sensitivity
where "Month_Start_Date">=date('2023-09-01')
)
,
price_sensitivity_percent_rank_med as (
select
"Month_Start_Date",
"Category",
median("Category_Price_Qty_Percent_Change") as "Category_Price_Qty_Percent_Change_Med",
median("Category_Price_Qty_Percent_Change_Percent_Rank") as "Category_Price_Qty_Percent_Change_Percent_Rank_Med"
from 
(
select distinct 
"Month_Start_Date",
"Category",
"Category_Price_Qty_Percent_Change",
"Category_Price_Qty_Percent_Change_Percent_Rank"
from price_sensitivity_percent_rank
order by "Month_Start_Date","Category","Category_Price_Qty_Percent_Change"
)
group by all
)

select distinct 
a.*, 
b."P12M_Store_Category_Compliance_Med",
b."P12M_Store_Category_Compliance_Percent_Rank_Med",
c.* exclude("Store_Code","Store_Name","Category","Month_Start_Date")
,current_date() as "Insertion_Date"
from compliance_percent_rank a
left join compliance_percent_rank_med b
on a."Category"=b."Category"
and a."Month_Start_Date"=b."Month_Start_Date"
left join (
select distinct 
a.*, 
b.*exclude("Category","Month_Start_Date")
from price_sensitivity_percent_rank a
left join price_sensitivity_percent_rank_med b
on a."Category"=b."Category"
and a."Month_Start_Date"=b."Month_Start_Date"
) c
on a."Category"=c."Category"
and a."Store_Code"=c."Store_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
order by a."Category",a."Month_Start_Date",a."P12M_Store_Category_Compliance_Percent_Rank"
)
;
