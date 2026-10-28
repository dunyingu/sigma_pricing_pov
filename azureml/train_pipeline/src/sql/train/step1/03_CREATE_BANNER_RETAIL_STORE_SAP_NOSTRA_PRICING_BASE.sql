create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE AS 
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_VW AS 
(
with store_product_month as 
(
SELECT DISTINCT d.*, date(c."Month_Start_Date") "Month_Start_Date"
FROM "EDP_PROD"."PRES"."Dim_Date" c
CROSS JOIN (SELECT DISTINCT "Store_Code","Product_Code"
FROM BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Nett_Price">0 and "Order_Quantity">=1
and "Cost_Price">0
--and "Nett_Price">"Cost_Price"
) d
WHERE date(c."Month_Start_Date") BETWEEN (SELECT min("Order_Month_Start_Date") FROM BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA) 
and (SELECT max("Order_Month_Start_Date") FROM BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA) 
)
,
meta as (
select distinct 
a."Store_Code",
h."State_Code" as "Store_State_Code",
b."MAP_PLANT_CODE",
c."Price_Group",
c."Retail_Pricing_Zone",
a."Product_Code",
e."Material_Group_1_Code",
case when j."Level_2_Name"!='UKN' and j."Level_2_Name"!='NA' and j."Level_2_Name"!='N/A' and j."Level_2_Name"!='Blank'then j."Level_2_Name"
     else null end AS Level2_Group,
case when j."Level_3_Name"!='UKN' and j."Level_3_Name"!='NA' and j."Level_3_Name"!='N/A' and j."Level_3_Name"!='Blank' then concat(j."Level_2_Name",'_',j."Level_3_Name") 
     else Level2_Group end AS Level3_Group,
case when j."Level_4_Name"!='UKN' and j."Level_4_Name"!='NA' and j."Level_4_Name"!='N/A' and j."Level_4_Name"!='Blank' then concat(j."Level_2_Name",'_',j."Level_3_Name",'_',j."Level_4_Name") 
     else Level3_Group end AS Level4_Group,
case when j."Level_5_Name"!='UKN' and j."Level_5_Name"!='NA' and j."Level_5_Name"!='N/A' and j."Level_5_Name"!='Blank' then concat(j."Level_2_Name",'_',j."Level_3_Name",'_',j."Level_4_Name",'_',j."Level_5_Name") 
     else Level4_Group end as Level5_Group,
--j."Manufacturer_Code",
case when j."Manufacturer_Name" NOT IN ('UKN','UNKNOWN','N/A','NA','BLANK') then j."Manufacturer_Name"
     else null end as "Manufacturer_Name",
case when j."Brand" NOT IN ('UKN','UNKNOWN','N/A','NA','BLANK') then j."Brand"
     else null end as "Brand",
concat("Manufacturer_Name",'_',"Brand") as "Manufacturer_Brand",
j."Active_Ingredient_1",
j."Form_And_Strength_Description",
j."PBS_Molecule_Name",
case when j."PBS_Molecule_Name" NOT IN ('UKN','UNKNOWN','N/A','NA','BLANK') then j."PBS_Molecule_Name" 
     when j."PBS_Molecule_Name" IN ('UKN','UNKNOWN','N/A','NA','BLANK') and j."Active_Ingredient_1" NOT IN ('UKN','UNKNOWN','N/A','NA','BLANK') then j."Active_Ingredient_1"
     when j."PBS_Molecule_Name" IN ('UKN','UNKNOWN','N/A','NA','BLANK') and j."Active_Ingredient_1" IN ('UKN','UNKNOWN','N/A','NA','BLANK') and j."Form_And_Strength_Description" NOT IN ('UKN','UNKNOWN','N/A','NA','BLANK') then j."Form_And_Strength_Description"
     else null end as "Active_Ingredient",
case when k."PBS_Item_Code" NOT IN ('UKN','UNKNOWN','N/A','NA','BLANK') then k."PBS_Item_Code"
     else null end as "PBS_Item_Code",
j."Is_PBS_Innovator_Flag",
j."Is_CSO_Eligible_Flag",
j."Is_Marked_for_Deletion_Flag",
j."Is_Core_Range_Flag",
j."KVI_Flag",
e."Is_Private_Label_Flag",
e."Is_NDSS_Flag",
e."Is_S100_Flag",
k."Drug_Type_Code",
k."Drug_Type_Description"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA a
left join (select * from MAP_CUSTOMER_RETAIL_STORE_PRODUCT_PLANT
QUALIFY ROW_NUMBER() OVER (PARTITION BY "Store_Code","Product_Code" ORDER BY "MAP_PLANT_CODE")=1
) b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
LEFT JOIN edp_prod.pres."Dim_Customer_Retail_Store" h
on a."Store_Code"=h."Store_Code"
--and h."Store_ID">0
left join edp_prod.pres."Dim_Salesforce_Customer" c
on h."Store_ID"=c."Store_ID"
and c."Price_Group" not in ('UKN','UNKNOWN','N/A','NA','BLANK')
and c."Retail_Pricing_Zone" not in ('UKN','UNKNOWN','N/A','NA','BLANK')
and c."Store_ID">0
left join "EDP_PROD"."PRES"."Dim_Product" j
ON a."Product_Code"=RIGHT(j."Product_Code",8)
left JOIN (SELECT * FROM "EDP_PROD"."PRES"."Dim_Sales_Org_Product"
QUALIFY ROW_NUMBER() OVER (PARTITION BY "Product_Code" ORDER BY "ETL_ROW_EFFECTIVE_DATE" desc)=1) e
ON a."Product_Code" = RIGHT(e."Product_Code",8)
left JOIN "EDP_PROD"."PRES"."Dim_PBS_Medicine" k
ON j."Current_PBS_Medicine_Key"=k."PBS_Medicine_Key"
--where a."Nett_Price">a."Cost_Price"
)
,
order_details as (
select 
a."Store_Code",
a."Product_Code",
a."Order_Month_Start_Date",
d."Monthly_Avg_Cost_Price",
e."Monthly_Avg_Start_Price",
a."Monthly_Avg_Nett_Price",
j."Monthly_Sigma_Avg_Nett_Price",
k."Monthly_NonSigma_Avg_Nett_Price",
round(100*(e."Monthly_Avg_Start_Price"-a."Monthly_Avg_Nett_Price")/e."Monthly_Avg_Start_Price",2) "Monthly_Avg_Discount",
round(100*(a."Monthly_Avg_Nett_Price"-d."Monthly_Avg_Cost_Price")/d."Monthly_Avg_Cost_Price",2) "Monthly_Avg_Margin",
nvl(b."Monthly_Total_Order_Quantity_Sigma",0) "Monthly_Sigma_Order_Quantity",
nvl(c."Monthly_Total_Order_Quantity_NonSigma",0) "Monthly_NonSigma_Order_Quantity",
round(100*"Monthly_Sigma_Order_Quantity"/a."Monthly_Total_Order_Quantity",2) as "Monthly_Compliance",
nvl(f."Monthly_Availability_Opportunity_Quantity",0) "Monthly_Sigma_Availability_Opportunity_Quantity",
a."Monthly_Number_Of_Orders",
nvl(b."Monthly_Sigma_Number_Of_Orders",0) "Monthly_Sigma_Number_Of_Orders",
nvl(c."Monthly_NonSigma_Number_Of_Orders",0) "Monthly_NonSigma_Number_Of_Orders",
a."Monthly_Total_Order_Quantity" as "Monthly_Store_Product_Order_Quantity",
round(a."Monthly_Total_Order_Quantity"/a."Monthly_Number_Of_Orders",0) "Monthly_Avg_Quantity_per_Order",
nvl(round(b."Monthly_Total_Order_Quantity_Sigma"/b."Monthly_Sigma_Number_Of_Orders",0),0) "Monthly_Sigma_Avg_Quantity_per_Order",
nvl(round(c."Monthly_Total_Order_Quantity_NonSigma"/c."Monthly_NonSigma_Number_Of_Orders",0),0) "Monthly_NonSigma_Avg_Quantity_per_Order",
nvl(g."Monthly_Wholesale_Promotion_Order_Quantity",0) "Monthly_Wholesale_Promotion_Order_Quantity",
nvl(h."Monthly_Sigma_Wholesale_Promotion_Order_Quantity",0) "Monthly_Sigma_Wholesale_Promotion_Order_Quantity",
nvl(i."Monthly_NonSigma_Wholesale_Promotion_Order_Quantity",0) "Monthly_NonSigma_Wholesale_Promotion_Order_Quantity"
from 
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
--count(distinct "Order_Date") "Monthly_Number_Of_Orders",
count("Order_Date") "Monthly_Number_Of_Orders",
sum("Nett_Price"*"Order_Quantity")/sum("Order_Quantity") as "Monthly_Avg_Nett_Price",
sum("Order_Quantity") "Monthly_Total_Order_Quantity"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Nett_Price">0 and "Order_Quantity">=1
and "Cost_Price">0
--and "Nett_Price">"Cost_Price"
group by 1,2,3) a
left join 
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
--count(distinct "Order_Date") "Monthly_Sigma_Number_Of_Orders",
count("Order_Date") "Monthly_Sigma_Number_Of_Orders",
sum("Order_Quantity") "Monthly_Total_Order_Quantity_Sigma"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Supplier_Master_Type_Name"='SIGMA' 
and  "Nett_Price">0 and "Order_Quantity">=1
and "Cost_Price">0
--and "Nett_Price">"Cost_Price"
group by 1,2,3) b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and a."Order_Month_Start_Date"=b."Order_Month_Start_Date"
left join 
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
--count(distinct "Order_Date") "Monthly_NonSigma_Number_Of_Orders",
count("Order_Date") "Monthly_NonSigma_Number_Of_Orders",
sum("Order_Quantity") "Monthly_Total_Order_Quantity_NonSigma"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Supplier_Master_Type_Name"!='SIGMA' 
and "Nett_Price">0 and "Order_Quantity">=1
and "Cost_Price">0
--and "Nett_Price">"Cost_Price"
group by 1,2,3) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Order_Month_Start_Date"=c."Order_Month_Start_Date"
left join
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Cost_Price"*"Order_Quantity")/sum("Order_Quantity") as "Monthly_Avg_Cost_Price"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Cost_Price" is not null
and "Cost_Price">0 and "Order_Quantity">=1
and "Nett_Price">0
--and "Nett_Price">"Cost_Price"
group by 1,2,3) d
on a."Store_Code"=d."Store_Code"
and a."Product_Code"=d."Product_Code"
and a."Order_Month_Start_Date"=d."Order_Month_Start_Date"
left join
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Start_Price"*"Order_Quantity")/sum("Order_Quantity") as "Monthly_Avg_Start_Price"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Start_Price" is not null
and "Start_Price">0 and "Order_Quantity">=1
and "Cost_Price">0 and "Nett_Price">0
--and "Nett_Price">"Cost_Price"
group by 1,2,3) e
on a."Store_Code"=e."Store_Code"
and a."Product_Code"=e."Product_Code"
and a."Order_Month_Start_Date"=e."Order_Month_Start_Date"
left join
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Availability_Opportunity_Quantity") "Monthly_Availability_Opportunity_Quantity"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Availability_Opportunity_Quantity" is not null
and "Cost_Price">0 and "Nett_Price">0 and "Order_Quantity">=1
--and "Nett_Price">"Cost_Price"
group by 1,2,3) f
on a."Store_Code"=f."Store_Code"
and a."Product_Code"=f."Product_Code"
and a."Order_Month_Start_Date"=f."Order_Month_Start_Date"
left join
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Order_Quantity") "Monthly_Wholesale_Promotion_Order_Quantity"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where 
"Cost_Price">0 and "Nett_Price">0 and "Order_Quantity">=1
--and "Nett_Price">"Cost_Price"
and "Promotion_Brief_Detail_Key"!=-1
group by 1,2,3
) g
on a."Store_Code"=g."Store_Code"
and a."Product_Code"=g."Product_Code"
and a."Order_Month_Start_Date"=g."Order_Month_Start_Date"
left join
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Order_Quantity") "Monthly_Sigma_Wholesale_Promotion_Order_Quantity"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Supplier_Master_Type_Name"='SIGMA' and
"Cost_Price">0 and "Nett_Price">0 and "Order_Quantity">=1
--and "Nett_Price">"Cost_Price"
and "Promotion_Brief_Detail_Key"!=-1
group by 1,2,3
) h
on a."Store_Code"=h."Store_Code"
and a."Product_Code"=h."Product_Code"
and a."Order_Month_Start_Date"=h."Order_Month_Start_Date"
left join
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Order_Quantity") "Monthly_NonSigma_Wholesale_Promotion_Order_Quantity"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Supplier_Master_Type_Name"!='SIGMA' and
"Cost_Price">0 and "Nett_Price">0 and "Order_Quantity">=1
--and "Nett_Price">"Cost_Price"
and "Promotion_Brief_Detail_Key"!=-1
group by 1,2,3
) i
on a."Store_Code"=i."Store_Code"
and a."Product_Code"=i."Product_Code"
and a."Order_Month_Start_Date"=i."Order_Month_Start_Date"
left join 
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Nett_Price"*"Order_Quantity")/sum("Order_Quantity") as "Monthly_Sigma_Avg_Nett_Price"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Supplier_Master_Type_Name"='SIGMA' and
"Nett_Price">0 and "Order_Quantity">=1
and "Cost_Price">0
--and "Nett_Price">"Cost_Price"
group by 1,2,3) j
on a."Store_Code"=j."Store_Code"
and a."Product_Code"=j."Product_Code"
and a."Order_Month_Start_Date"=j."Order_Month_Start_Date"
left join 
(select "Store_Code",
"Product_Code",
"Order_Month_Start_Date",
sum("Nett_Price"*"Order_Quantity")/sum("Order_Quantity") as "Monthly_NonSigma_Avg_Nett_Price"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Supplier_Master_Type_Name"!='SIGMA' and
"Nett_Price">0 and "Order_Quantity">=1
and "Cost_Price">0
--and "Nett_Price">"Cost_Price"
group by 1,2,3) k
on a."Store_Code"=k."Store_Code"
and a."Product_Code"=k."Product_Code"
and a."Order_Month_Start_Date"=k."Order_Month_Start_Date"
)
,
order_agg as (
select distinct 
"Store_Code",
"Product_Code",
"Order_Month_Start_Date",
Level2_Group,
Level3_Group,
Level4_Group,
Level5_Group,
"Manufacturer_Name",
"Brand",
"Manufacturer_Brand",
"Active_Ingredient",
"PBS_Item_Code",
greatest(round("Monthly_Store_Level2_Order_Quantity",0),0) as "Monthly_Store_Level2_Order_Quantity",
greatest(round("Monthly_Store_Level3_Order_Quantity",0),0) as "Monthly_Store_Level3_Order_Quantity",
greatest(round("Monthly_Store_Level4_Order_Quantity",0),0) as "Monthly_Store_Level4_Order_Quantity",
greatest(round("Monthly_Store_Level5_Order_Quantity",0),0) as "Monthly_Store_Level5_Order_Quantity",
greatest(round("Monthly_Store_Manufacturer_Order_Quantity",0),0) as "Monthly_Store_Manufacturer_Order_Quantity",
greatest(round("Monthly_Store_Manufacturer_Brand_Order_Quantity",0),0) as "Monthly_Store_Manufacturer_Brand_Order_Quantity",
greatest(round("Monthly_Store_Active_Ingredient_Order_Quantity",0),0) as "Monthly_Store_Active_Ingredient_Order_Quantity",
greatest(round("Monthly_Store_PBS_Item_Code_Order_Quantity",0),0) as "Monthly_Store_PBS_Item_Code_Order_Quantity"
from 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Order_Month_Start_Date",
g.Level2_Group,
g.Level3_Group,
g.Level4_Group,
g.Level5_Group,
g."Manufacturer_Name",
g."Brand",
g."Manufacturer_Brand",
g."Active_Ingredient",
g."PBS_Item_Code",
a."Order_Quantity",
sum(case when g.Level2_Group is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g.Level2_Group) "Monthly_Store_Level2_Order_Quantity",
sum(case when g.Level3_Group is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g.Level3_Group) "Monthly_Store_Level3_Order_Quantity",
sum(case when g.Level4_Group is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g.Level4_Group) "Monthly_Store_Level4_Order_Quantity",
sum(case when g.Level5_Group is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g.Level5_Group) "Monthly_Store_Level5_Order_Quantity",
sum(case when g."Manufacturer_Name" is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g."Manufacturer_Name") "Monthly_Store_Manufacturer_Order_Quantity",
sum(case when g."Manufacturer_Brand" is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g."Manufacturer_Brand") "Monthly_Store_Manufacturer_Brand_Order_Quantity",
sum(case when g."Active_Ingredient" is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g."Active_Ingredient") "Monthly_Store_Active_Ingredient_Order_Quantity",
sum(case when g."PBS_Item_Code" is not null then a."Order_Quantity" else null end) over (partition by a."Store_Code","Order_Month_Start_Date",g."PBS_Item_Code") "Monthly_Store_PBS_Item_Code_Order_Quantity"
from 
BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA a
left join meta g
on a."Store_Code"=g."Store_Code"
and a."Product_Code"=g."Product_Code"
and a."Cost_Price">0 
and a."Nett_Price">0 
and a."Order_Quantity">=1
--and round(a."Order_Quantity",0)>=1
--and a."Nett_Price">a."Cost_Price"
)
)
,
order_total as (
select 
"Store_Code",
"Order_Month_Start_Date",
sum("Order_Quantity") "Monthly_Store_Total_Order_Quantity"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Cost_Price">0 
and "Nett_Price">0 
and "Order_Quantity">=1
--and "Nett_Price">"Cost_Price"
group by 1,2
)
,
days_in_month as (
select distinct 
"Month_Start_Date",
datediff('day',"Month_Start_Date",dateadd('month',1,"Month_Start_Date")-1)+1 as "Days_In_Month",
dateadd('month',1,"Month_Start_Date")-1 as "Month_End_Date"
from store_product_month
)
,
holidays as (
SELECT DISTINCT
"Month_Start_Date",
"State",
"Month_Holiday_Cnt",
"Month_First_Holiday_Date",
"Month_Last_Holiday_Date",
"Month_Holiday_DaysInBetween",
LEAD("Month_Holiday_Cnt") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Next_Month_Holiday_Cnt",
LEAD("Month_First_Holiday_Date") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Next_Month_First_Holiday_Date",
Lag("Month_Holiday_Cnt") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Previous_Month_Holiday_Cnt",
Lag("Month_Last_Holiday_Date") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Previous_Month_Last_Holiday_Date",
"Next_Month_First_Holiday_Date"-"Month_End_Date" as "Days_to_Next_Month_First_Holiday",
"Month_Start_Date"-"Previous_Month_Last_Holiday_Date" as "Days_from_Previous_Month_Last_Holiday"
from
(select 
distinct 
a.*,
nvl(b."Month_Holiday_Cnt",0) as "Month_Holiday_Cnt",
b."Month_First_Holiday_Date",
b."Month_Last_Holiday_Date",
b."Month_Holiday_DaysInBetween"
from (SELECT c.*,
b."State"
FROM days_in_month c
CROSS JOIN (SELECT DISTINCT "Store_State_Code" AS "State" FROM meta) b) a
left join core.AU_PUBLIC_HOLIDAYS_MONTH_VW b
on a."Month_Start_Date"=b."Month_Start_Date"
AND a."State"=b."State"
)
)
,
plant_prod_avail as (
select distinct
a."Plant_Code",
a."Product_Code",
b."Month_Start_Date",
least(a."MCS_Days_In_Month",b."Days_In_Month") as "Sigma_MCS_Days_In_Month",
least(a."OOS_Days_In_Month",b."Days_In_Month") as "Sigma_OOS_Days_In_Month"
--b."Days_In_Month",
--round(100*"Sigma_MCS_Days_In_Month"/b."Days_In_Month",2) as "Sigma_MCS_Days_Percent_In_Month",
--round(100*"Sigma_OOS_Days_In_Month"/b."Days_In_Month",2) as "Sigma_OOS_Days_Percent_In_Month"
from 
days_in_month b
left join 
(select 
"Plant_Code",
"Product_Code",
"Month_Start_Date",
sum("MCS Days") as "MCS_Days_In_Month" ,
sum("OOS Days") as "OOS_Days_In_Month"
from (
select distinct 
"Plant Code" as "Plant_Code",
right("Product Code",8) "Product_Code",
date("Week Start Date") "Week_Start_Date",
date_trunc('month',date("Week Start Date")) "Month_Start_Date",
"MCS Days",
"OOS Days"
from core.agg_availabity_weekly_vw
)
group by 1,2,3) a
on b."Month_Start_Date"=a."Month_Start_Date"
)
,
state_prod_avail as (
select 
"Plant_State",
"Product_Code",
"Month_Start_Date",
max("Sigma_MCS_Days_In_Month") "Sigma_State_MCS_Days_In_Month",
max("Sigma_OOS_Days_In_Month") "Sigma_State_OOS_Days_In_Month"
from 
(select distinct 
a."Plant_Code",
b."Plant_State",
a."Product_Code",
a."Month_Start_Date",
a."Sigma_MCS_Days_In_Month",
a."Sigma_OOS_Days_In_Month"
from plant_prod_avail a
left join edp_prod.pres."Dim_Plant" b
on a."Plant_Code"=b."Plant_Code" 
)
group by 1,2,3
)
,
retail_sales_prod as (
select "Store_Code",
"Product_Code",
date_trunc('month',"Sales_Date") "Sales_Month_Start_Date",
greatest(round(sum("Sales_Quantity"),0),0) "Monthly_Store_Product_Sales_Quantity",
greatest(sum("Sales_Ex_GST_Amount"),0) "Monthly_Store_Product_Sales_Amount"
from 
(
select distinct 
a."Customer_Retail_Store_Key",
e."Store_Code",
a."Product_Retail_Master_Key",
RIGHT(c."Product_Code",8) "Product_Code",
a."Is_Script",
a."Sales_Code",
a."Sales_Line_Code",
date(a."Sales_Date_Key",'YYYYMMDD') "Sales_Date",
--date_trunc('month',"Sales_Date") "Sales_Month_Start_Date",
a."Sales_Quantity",
--,round(a."Sales_Quantity",0),
--a."COGS_Amount",
--a."GST_Amount",
a."Sales_Ex_GST_Amount"
--a."Discount_Ex_GST_Amount",
--a."Gross_Margin_Amount",
--a."Gross_Profit_Amount"
from 
edp_prod.pres."Fact_Retail_POS" a
left join edp_prod.pres."Dim_Customer_Retail_Store" e
ON a."Customer_Retail_Store_Key" = e."Customer_Retail_Store_Key"
left JOIN edp_prod.pres."Dim_Customer" f
ON e."Site_Link_Code" = f."Site_Link_Code"
and f."Distribution_Channel_Name"='WHOLESALE'
left join edp_prod.pres."Dim_Product_Retail_Master" b
on a."Product_Retail_Master_Key" = b."Product_Retail_Master_Key"
left JOIN edp_prod.pres."Dim_Product" c
ON b."Primary_Wholesale_Product_Key"=c."Product_Key"
and c."Product_Key">0
where a."Customer_Retail_Store_Key" is not null --and a."Customer_Retail_Store_Key"!='N/A'
and e."Store_Code" IS NOT NULL AND e."Site_Link_Code" IS NOT NULL 
AND e."Store_Code"!='N/A' AND e."Site_Link_Code"!='N/A'
AND e."Store_Code"!='NA' AND e."Site_Link_Code"!='NA'
AND e."Store_Code"!='UKN' AND e."Site_Link_Code"!='UKN'
and f."Customer_Key">0
and c."Product_Code" is not null and c."Product_Code"!='N/A'
and c."Product_Code"!='NA' and c."Product_Code"!='UKN'
--and round(a."Sales_Quantity",0)>=1
)
group by 1,2,3
)
,
retail_sales_agg as (
select distinct 
"Store_Code",
"Product_Code",
"Sales_Month_Start_Date",
Level2_Group,
Level3_Group,
Level4_Group,
Level5_Group,
"Manufacturer_Name",
"Brand",
"Manufacturer_Brand",
"Active_Ingredient",
"PBS_Item_Code",
greatest(round("Monthly_Store_Level2_Sales_Quantity",0),0) as "Monthly_Store_Level2_Sales_Quantity",
greatest(round("Monthly_Store_Level3_Sales_Quantity",0),0) as "Monthly_Store_Level3_Sales_Quantity",
greatest(round("Monthly_Store_Level4_Sales_Quantity",0),0) as "Monthly_Store_Level4_Sales_Quantity",
greatest(round("Monthly_Store_Level5_Sales_Quantity",0),0) as "Monthly_Store_Level5_Sales_Quantity",
greatest(round("Monthly_Store_Manufacturer_Sales_Quantity",0),0) as "Monthly_Store_Manufacturer_Sales_Quantity",
greatest(round("Monthly_Store_Manufacturer_Brand_Sales_Quantity",0),0) as "Monthly_Store_Manufacturer_Brand_Sales_Quantity",
greatest(round("Monthly_Store_Active_Ingredient_Sales_Quantity",0),0) as "Monthly_Store_Active_Ingredient_Sales_Quantity",
greatest(round("Monthly_Store_PBS_Item_Code_Sales_Quantity",0),0) as "Monthly_Store_PBS_Item_Code_Sales_Quantity",
greatest("Monthly_Store_Level2_Sales_Amount",0) as "Monthly_Store_Level2_Sales_Amount",
greatest("Monthly_Store_Level3_Sales_Amount",0) as "Monthly_Store_Level3_Sales_Amount",
greatest("Monthly_Store_Level4_Sales_Amount",0) as "Monthly_Store_Level4_Sales_Amount",
greatest("Monthly_Store_Level5_Sales_Amount",0) as "Monthly_Store_Level5_Sales_Amount",
greatest("Monthly_Store_Manufacturer_Sales_Amount",0) as "Monthly_Store_Manufacturer_Sales_Amount",
greatest("Monthly_Store_Manufacturer_Brand_Sales_Amount",0) as "Monthly_Store_Manufacturer_Brand_Sales_Amount",
greatest("Monthly_Store_Active_Ingredient_Sales_Amount",0) as "Monthly_Store_Active_Ingredient_Sales_Amount",
greatest("Monthly_Store_PBS_Item_Code_Sales_Amount",0) as "Monthly_Store_PBS_Item_Code_Sales_Amount"
from 
(
select distinct 
a."Customer_Retail_Store_Key",
e."Store_Code",
a."Product_Retail_Master_Key",
RIGHT(c."Product_Code",8) "Product_Code",
g.Level2_Group,
g.Level3_Group,
g.Level4_Group,
g.Level5_Group,
g."Manufacturer_Name",
g."Brand",
g."Manufacturer_Brand",
g."Active_Ingredient",
g."PBS_Item_Code",
a."Is_Script",
a."Sales_Code",
a."Sales_Line_Code",
date(a."Sales_Date_Key",'YYYYMMDD') "Sales_Date",
date_trunc('month',"Sales_Date") "Sales_Month_Start_Date",
a."Sales_Quantity",
--round(a."Sales_Quantity",0),
a."Sales_Ex_GST_Amount",
sum(case when g.Level2_Group is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level2_Group) "Monthly_Store_Level2_Sales_Quantity",
sum(case when g.Level3_Group is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level3_Group) "Monthly_Store_Level3_Sales_Quantity",
sum(case when g.Level4_Group is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level4_Group) "Monthly_Store_Level4_Sales_Quantity",
sum(case when g.Level5_Group is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level5_Group) "Monthly_Store_Level5_Sales_Quantity",
sum(case when g."Manufacturer_Name" is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."Manufacturer_Name") "Monthly_Store_Manufacturer_Sales_Quantity",
sum(case when g."Manufacturer_Brand" is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."Manufacturer_Brand") "Monthly_Store_Manufacturer_Brand_Sales_Quantity",
sum(case when g."Active_Ingredient" is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."Active_Ingredient") "Monthly_Store_Active_Ingredient_Sales_Quantity",
sum(case when g."PBS_Item_Code" is not null then a."Sales_Quantity" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."PBS_Item_Code") "Monthly_Store_PBS_Item_Code_Sales_Quantity",
sum(case when g.Level2_Group is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level2_Group) "Monthly_Store_Level2_Sales_Amount",
sum(case when g.Level3_Group is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level3_Group) "Monthly_Store_Level3_Sales_Amount",
sum(case when g.Level4_Group is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level4_Group) "Monthly_Store_Level4_Sales_Amount",
sum(case when g.Level5_Group is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g.Level5_Group) "Monthly_Store_Level5_Sales_Amount",
sum(case when g."Manufacturer_Name" is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."Manufacturer_Name") "Monthly_Store_Manufacturer_Sales_Amount",
sum(case when g."Manufacturer_Brand" is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."Manufacturer_Brand") "Monthly_Store_Manufacturer_Brand_Sales_Amount",
sum(case when g."Active_Ingredient" is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."Active_Ingredient") "Monthly_Store_Active_Ingredient_Sales_Amount",
sum(case when g."PBS_Item_Code" is not null then a."Sales_Ex_GST_Amount" else null end) over (partition by e."Store_Code","Sales_Month_Start_Date",g."PBS_Item_Code") "Monthly_Store_PBS_Item_Code_Sales_Amount"
from 
edp_prod.pres."Fact_Retail_POS" a
left join edp_prod.pres."Dim_Customer_Retail_Store" e
ON a."Customer_Retail_Store_Key" = e."Customer_Retail_Store_Key"
left JOIN edp_prod.pres."Dim_Customer" f
ON e."Site_Link_Code" = f."Site_Link_Code"
and f."Distribution_Channel_Name"='WHOLESALE'
left join edp_prod.pres."Dim_Product_Retail_Master" b
on a."Product_Retail_Master_Key" = b."Product_Retail_Master_Key"
left JOIN edp_prod.pres."Dim_Product" c
ON b."Primary_Wholesale_Product_Key"=c."Product_Key"
and c."Product_Key">0
inner join meta g
on e."Store_Code"=g."Store_Code"
and RIGHT(c."Product_Code",8)=g."Product_Code"
where a."Customer_Retail_Store_Key" is not null --and a."Customer_Retail_Store_Key"!='N/A'
and e."Store_Code" IS NOT NULL AND e."Site_Link_Code" IS NOT NULL 
AND e."Store_Code"!='N/A' AND e."Site_Link_Code"!='N/A'
AND e."Store_Code"!='NA' AND e."Site_Link_Code"!='NA'
AND e."Store_Code"!='UKN' AND e."Site_Link_Code"!='UKN'
and f."Customer_Key">0
and c."Product_Code" is not null and c."Product_Code"!='N/A'
and c."Product_Code"!='NA' and c."Product_Code"!='UKN'
--and round(a."Sales_Quantity",0)>=1
)
)
,
retail_sales_total as (
select "Store_Code",
date_trunc('month',"Sales_Date") "Sales_Month_Start_Date",
count(distinct "Sales_Code") "Monthly_Store_Visit_Cnt",
greatest(round(sum("Sales_Quantity"),0),0) "Monthly_Store_Total_Sales_Quantity",
greatest(sum("Sales_Ex_GST_Amount"),0) "Monthly_Store_Total_Sales_Amount"
from 
(
select distinct 
a."Customer_Retail_Store_Key",
e."Store_Code",
a."Product_Retail_Master_Key",
RIGHT(c."Product_Code",8) "Product_Code",
a."Is_Script",
a."Sales_Code",
a."Sales_Line_Code",
date(a."Sales_Date_Key",'YYYYMMDD') "Sales_Date",
--date_trunc('month',"Sales_Date") "Sales_Month_Start_Date",
a."Sales_Quantity",
--,round(a."Sales_Quantity",0),
--a."COGS_Amount",
--a."GST_Amount",
a."Sales_Ex_GST_Amount"
--a."Discount_Ex_GST_Amount",
--a."Gross_Margin_Amount",
--a."Gross_Profit_Amount"
from 
edp_prod.pres."Fact_Retail_POS" a
left join edp_prod.pres."Dim_Customer_Retail_Store" e
ON a."Customer_Retail_Store_Key" = e."Customer_Retail_Store_Key"
left JOIN edp_prod.pres."Dim_Customer" f
ON e."Site_Link_Code" = f."Site_Link_Code"
and f."Distribution_Channel_Name"='WHOLESALE'
left join edp_prod.pres."Dim_Product_Retail_Master" b
on a."Product_Retail_Master_Key" = b."Product_Retail_Master_Key"
left JOIN edp_prod.pres."Dim_Product" c
ON b."Primary_Wholesale_Product_Key"=c."Product_Key"
and c."Product_Key">0
where a."Customer_Retail_Store_Key" is not null --and a."Customer_Retail_Store_Key"!='N/A'
and e."Store_Code" IS NOT NULL AND e."Site_Link_Code" IS NOT NULL 
AND e."Store_Code"!='N/A' AND e."Site_Link_Code"!='N/A'
AND e."Store_Code"!='NA' AND e."Site_Link_Code"!='NA'
AND e."Store_Code"!='UKN' AND e."Site_Link_Code"!='UKN'
and f."Customer_Key">0
and c."Product_Code" is not null and c."Product_Code"!='N/A'
and c."Product_Code"!='NA' and c."Product_Code"!='UKN'
--and round(a."Sales_Quantity",0)>=1
)
group by 1,2
)
,
retail_sales_prod_promo as (
select "Store_Code",
"Product_Code",
date_trunc('month',"Sales_Date") "Sales_Month_Start_Date",
greatest(round(sum("Sales_Quantity"),0),0) "Monthly_Store_Product_Promotion_Sales_Quantity",
greatest(sum("Sales_Ex_GST_Amount"),0) "Monthly_Store_Product_Promotion_Sales_Amount",
greatest(sum("Discount_Ex_GST_Amount"),0) "Monthly_Store_Product_Promotion_Discount_Amount"
from 
(
select distinct 
a."Customer_Retail_Store_Key",
e."Store_Code",
a."Product_Retail_Master_Key",
RIGHT(c."Product_Code",8) "Product_Code",
a."Is_Script",
a."Sales_Code",
a."Sales_Line_Code",
date(a."Sales_Date_Key",'YYYYMMDD') "Sales_Date",
--date_trunc('month',"Sales_Date") "Sales_Month_Start_Date",
a."Sales_Quantity",
--,round(a."Sales_Quantity",0),
--a."COGS_Amount",
--a."GST_Amount",
a."Sales_Ex_GST_Amount",
a."Discount_Ex_GST_Amount"
--a."Gross_Margin_Amount",
--a."Gross_Profit_Amount"
from 
edp_prod.pres."Fact_Retail_POS" a
left join edp_prod.pres."Dim_Customer_Retail_Store" e
ON a."Customer_Retail_Store_Key" = e."Customer_Retail_Store_Key"
left JOIN edp_prod.pres."Dim_Customer" f
ON e."Site_Link_Code" = f."Site_Link_Code"
and f."Distribution_Channel_Name"='WHOLESALE'
left join edp_prod.pres."Dim_Product_Retail_Master" b
on a."Product_Retail_Master_Key" = b."Product_Retail_Master_Key"
left JOIN edp_prod.pres."Dim_Product" c
ON b."Primary_Wholesale_Product_Key"=c."Product_Key"
and c."Product_Key">0
where a."Customer_Retail_Store_Key" is not null --and a."Customer_Retail_Store_Key"!='N/A'
and e."Store_Code" IS NOT NULL AND e."Site_Link_Code" IS NOT NULL 
AND e."Store_Code"!='N/A' AND e."Site_Link_Code"!='N/A'
AND e."Store_Code"!='NA' AND e."Site_Link_Code"!='NA'
AND e."Store_Code"!='UKN' AND e."Site_Link_Code"!='UKN'
and f."Customer_Key">0
and c."Product_Code" is not null and c."Product_Code"!='N/A'
and c."Product_Code"!='NA' and c."Product_Code"!='UKN'
--and round(a."Sales_Quantity",0)>=1
and a."Promotion_Brief_Detail_Key"!=-1
)
group by 1,2,3
)

select 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
month(a."Month_Start_Date") "MonthofYear",
b."Store_State_Code",
b."MAP_PLANT_CODE",
b."Price_Group",
b."Retail_Pricing_Zone",
b."Material_Group_1_Code",
b.Level2_Group,
b.Level3_Group,
b.Level4_Group,
b.Level5_Group,
b."Manufacturer_Name",
b."Brand",
b."Manufacturer_Brand",
b."Active_Ingredient",
b."PBS_Item_Code",
b."Is_PBS_Innovator_Flag",
b."Is_CSO_Eligible_Flag",
b."Is_Marked_for_Deletion_Flag",
b."Is_Core_Range_Flag",
b."KVI_Flag",
b."Is_Private_Label_Flag",
b."Is_NDSS_Flag",
b."Is_S100_Flag",
b."Drug_Type_Code",
b."Drug_Type_Description",
c."Days_In_Month",
c."Month_End_Date",
nvl(d."Month_Holiday_Cnt",0) "Month_Holiday_Cnt",
d."Month_First_Holiday_Date",
d."Month_Last_Holiday_Date",
d."Month_Holiday_DaysInBetween",
nvl(d."Next_Month_Holiday_Cnt",0) "Next_Month_Holiday_Cnt",
d."Next_Month_First_Holiday_Date",
nvl(d."Previous_Month_Holiday_Cnt",0) "Previous_Month_Holiday_Cnt",
d."Previous_Month_Last_Holiday_Date",
d."Days_to_Next_Month_First_Holiday",
d."Days_from_Previous_Month_Last_Holiday",
case when e."Sigma_MCS_Days_In_Month" is not null then e."Sigma_MCS_Days_In_Month"
     else f."Sigma_State_MCS_Days_In_Month" end as "MCS_Days_In_Month",
case when e."Sigma_OOS_Days_In_Month" is not null then e."Sigma_OOS_Days_In_Month"
     else f."Sigma_State_OOS_Days_In_Month" end as "OOS_Days_In_Month",
round(100*"MCS_Days_In_Month"/c."Days_In_Month",2) as "MCS_Days_Percent_In_Month",
round(100*"OOS_Days_In_Month"/c."Days_In_Month",2) as "OOS_Days_Percent_In_Month",
case when b.Level2_Group is not null then nvl(h."Monthly_Store_Level2_Sales_Quantity",0)
      else null end as "Monthly_Store_Level2_Sales_Quantity",
case when b.Level3_Group is not null then nvl(h."Monthly_Store_Level3_Sales_Quantity",0)
      else null end as "Monthly_Store_Level3_Sales_Quantity",
case when b.Level4_Group is not null then nvl(h."Monthly_Store_Level4_Sales_Quantity",0)
      else null end as "Monthly_Store_Level4_Sales_Quantity",
case when b.Level5_Group is not null then nvl(h."Monthly_Store_Level5_Sales_Quantity",0)
      else null end as "Monthly_Store_Level5_Sales_Quantity",
case when b."Manufacturer_Name" is not null then nvl(h."Monthly_Store_Manufacturer_Sales_Quantity",0) 
      else null end as "Monthly_Store_Manufacturer_Sales_Quantity",
case when b."Manufacturer_Brand" is not null then nvl(h."Monthly_Store_Manufacturer_Brand_Sales_Quantity",0) 
      else null end as "Monthly_Store_Manufacturer_Brand_Sales_Quantity",
case when b."Active_Ingredient" is not null then nvl(h."Monthly_Store_Active_Ingredient_Sales_Quantity",0) 
      else null end as "Monthly_Store_Active_Ingredient_Sales_Quantity",
case when b."PBS_Item_Code" is not null then nvl(h."Monthly_Store_PBS_Item_Code_Sales_Quantity",0) 
      else null end as "Monthly_Store_PBS_Item_Code_Sales_Quantity",
case when b.Level2_Group is not null then nvl(h."Monthly_Store_Level2_Sales_Amount",0)
      else null end as "Monthly_Store_Level2_Sales_Amount",
case when b.Level3_Group is not null then nvl(h."Monthly_Store_Level3_Sales_Amount",0)
      else null end as "Monthly_Store_Level3_Sales_Amount",
case when b.Level4_Group is not null then nvl(h."Monthly_Store_Level4_Sales_Amount",0)
      else null end as "Monthly_Store_Level4_Sales_Amount",
case when b.Level5_Group is not null then nvl(h."Monthly_Store_Level5_Sales_Amount",0)
      else null end as "Monthly_Store_Level5_Sales_Amount",
case when b."Manufacturer_Name" is not null then nvl(h."Monthly_Store_Manufacturer_Sales_Amount",0) 
      else null end as "Monthly_Store_Manufacturer_Sales_Amount",
case when b."Manufacturer_Brand" is not null then nvl(h."Monthly_Store_Manufacturer_Brand_Sales_Amount",0) 
      else null end as "Monthly_Store_Manufacturer_Brand_Sales_Amount",
case when b."Active_Ingredient" is not null then nvl(h."Monthly_Store_Active_Ingredient_Sales_Amount",0) 
      else null end as "Monthly_Store_Active_Ingredient_Sales_Amount",
case when b."PBS_Item_Code" is not null then nvl(h."Monthly_Store_PBS_Item_Code_Sales_Amount",0) 
      else null end as "Monthly_Store_PBS_Item_Code_Sales_Amount",
nvl(g."Monthly_Store_Product_Sales_Quantity",0) "Monthly_Store_Product_Sales_Quantity",
nvl(g."Monthly_Store_Product_Sales_Amount",0) "Monthly_Store_Product_Sales_Amount",
nvl(m."Monthly_Store_Visit_Cnt",0) "Monthly_Store_Visit_Cnt",
nvl(m."Monthly_Store_Total_Sales_Quantity",0) "Monthly_Store_Total_Sales_Quantity",
nvl(m."Monthly_Store_Total_Sales_Amount",0) "Monthly_Store_Total_Sales_Amount",
nvl(n."Monthly_Store_Product_Promotion_Sales_Quantity",0) "Monthly_Store_Product_Promotion_Sales_Quantity",
nvl(n."Monthly_Store_Product_Promotion_Sales_Amount",0) "Monthly_Store_Product_Promotion_Sales_Amount",
nvl(n."Monthly_Store_Product_Promotion_Discount_Amount",0) "Monthly_Store_Product_Promotion_Discount_Amount",
nvl(p."Monthly_Store_Total_Order_Quantity",0) "Monthly_Store_Total_Order_Quantity",
case when b.Level2_Group is not null then nvl(j."Monthly_Store_Level2_Order_Quantity",0) 
      else null end as "Monthly_Store_Level2_Order_Quantity",
case when b.Level3_Group is not null then nvl(j."Monthly_Store_Level3_Order_Quantity",0) 
      else null end as "Monthly_Store_Level3_Order_Quantity",
case when b.Level4_Group is not null then nvl(j."Monthly_Store_Level4_Order_Quantity",0) 
      else null end as "Monthly_Store_Level4_Order_Quantity",
case when b.Level5_Group is not null then nvl(j."Monthly_Store_Level5_Order_Quantity",0) 
      else null end as "Monthly_Store_Level5_Order_Quantity",
case when b."Manufacturer_Name" is not null then nvl(j."Monthly_Store_Manufacturer_Order_Quantity",0) 
      else null end as "Monthly_Store_Manufacturer_Order_Quantity",
case when b."Manufacturer_Brand" is not null then nvl(j."Monthly_Store_Manufacturer_Brand_Order_Quantity",0) 
      else null end as "Monthly_Store_Manufacturer_Brand_Order_Quantity",
case when b."Active_Ingredient" is not null then nvl(j."Monthly_Store_Active_Ingredient_Order_Quantity",0) 
      else null end as "Monthly_Store_Active_Ingredient_Order_Quantity",
case when b."PBS_Item_Code" is not null then nvl(j."Monthly_Store_PBS_Item_Code_Order_Quantity",0) 
      else null end as "Monthly_Store_PBS_Item_Code_Order_Quantity",
k."Monthly_Avg_Cost_Price",
k."Monthly_Avg_Start_Price",
k."Monthly_Avg_Nett_Price",
k."Monthly_Sigma_Avg_Nett_Price",
k."Monthly_NonSigma_Avg_Nett_Price",
k."Monthly_Avg_Discount",
k."Monthly_Avg_Margin",
nvl(k."Monthly_Sigma_Order_Quantity",0) "Monthly_Store_Product_Sigma_Order_Quantity",
nvl(k."Monthly_NonSigma_Order_Quantity",0) "Monthly_Store_Product_NonSigma_Order_Quantity",
k."Monthly_Compliance",
nvl(k."Monthly_Wholesale_Promotion_Order_Quantity",0) "Monthly_Wholesale_Promotion_Order_Quantity",
nvl(k."Monthly_Sigma_Wholesale_Promotion_Order_Quantity",0) "Monthly_Sigma_Wholesale_Promotion_Order_Quantity",
nvl(k."Monthly_NonSigma_Wholesale_Promotion_Order_Quantity",0) "Monthly_NonSigma_Wholesale_Promotion_Order_Quantity",
round(nvl(k."Monthly_Sigma_Availability_Opportunity_Quantity",0),0) "Monthly_Sigma_Availability_Opportunity_Quantity",
nvl(k."Monthly_Number_Of_Orders",0) "Monthly_Store_Product_Number_Of_Orders",
nvl(k."Monthly_Sigma_Number_Of_Orders",0) "Monthly_Store_Product_Sigma_Number_Of_Orders",
nvl(k."Monthly_NonSigma_Number_Of_Orders",0) "Monthly_Store_Product_NonSigma_Number_Of_Orders",
nvl(k."Monthly_Avg_Quantity_per_Order",0) "Monthly_Store_Product_Avg_Quantity_per_Order",
nvl(k."Monthly_Sigma_Avg_Quantity_per_Order",0) "Monthly_Store_Product_Sigma_Avg_Quantity_per_Order",
nvl(k."Monthly_NonSigma_Avg_Quantity_per_Order",0) "Monthly_Store_Product_NonSigma_Avg_Quantity_per_Order",
nvl(k."Monthly_Store_Product_Order_Quantity",0) "Monthly_Store_Product_Order_Quantity",
current_date() as "Insertion_Date"
from store_product_month a
left join meta b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
left join days_in_month c
on a."Month_Start_Date"=c."Month_Start_Date"
left join holidays d
on a."Month_Start_Date"=d."Month_Start_Date"
and b."Store_State_Code"=d."State"
left join plant_prod_avail e
on b."MAP_PLANT_CODE"=e."Plant_Code"
and a."Product_Code"=e."Product_Code"
and a."Month_Start_Date"=e."Month_Start_Date"
left join state_prod_avail f
on b."Store_State_Code"=f."Plant_State"
and a."Product_Code"=f."Product_Code"
and a."Month_Start_Date"=f."Month_Start_Date"
left join retail_sales_prod g
on a."Store_Code"=g."Store_Code"
and a."Product_Code"=g."Product_Code"
and a."Month_Start_Date"=g."Sales_Month_Start_Date"
left join retail_sales_agg h
on a."Store_Code"=h."Store_Code"
and a."Product_Code"=h."Product_Code"
and a."Month_Start_Date"=h."Sales_Month_Start_Date"
left join retail_sales_total m
on a."Store_Code"=m."Store_Code"
--and a."Product_Code"=m."Product_Code"
and a."Month_Start_Date"=m."Sales_Month_Start_Date"
left join retail_sales_prod_promo n
on a."Store_Code"=n."Store_Code"
and a."Product_Code"=n."Product_Code"
and a."Month_Start_Date"=n."Sales_Month_Start_Date"
left join order_total p 
on a."Store_Code"=p."Store_Code"
--and a."Product_Code"=p."Product_Code"
and a."Month_Start_Date"=p."Order_Month_Start_Date"
left join order_agg  j
on a."Store_Code"=j."Store_Code"
and a."Product_Code"=j."Product_Code"
and a."Month_Start_Date"=j."Order_Month_Start_Date"
left join order_details k
on a."Store_Code"=k."Store_Code"
and a."Product_Code"=k."Product_Code"
and a."Month_Start_Date"=k."Order_Month_Start_Date"
order by a."Store_Code",a."Product_Code",a."Month_Start_Date"
)
;
