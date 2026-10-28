CREATE OR REPLACE TABLE BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA_POC AS 
--CREATE OR REPLACE VIEW BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA_POC_VW  AS
(
with store_summ as (
select 
a."Store_Code",
j."Material_Group_1_Code",
sum(a."Nett_Price"*a."Order_Quantity") as "Store_Nett_Amount"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA a
left JOIN (SELECT * FROM "EDP_PROD"."PRES"."Dim_Sales_Org_Product"
QUALIFY ROW_NUMBER() OVER (PARTITION BY "Product_Code" ORDER BY "ETL_ROW_EFFECTIVE_DATE" desc)=1)  j
ON a."Product_Code" = RIGHT(j."Product_Code",8)
where a."Order_Date" >= date('2021-09-01') and a."Order_Date"<=date('2023-12-31')
and  a."Nett_Price">0 and a."Order_Quantity">=1
--and a."Nett_Price">a."Cost_Price"
group by 1,2
)
,
store_product_summ as (
select 
"Store_Code",
"Product_Code",
sum("Nett_Price"*"Order_Quantity") as "Store_Product_Nett_Amount"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA a
where "Order_Date" >= date('2021-09-01') and "Order_Date"<=date('2023-12-31')
and  "Nett_Price">0 and "Order_Quantity">=1
--and a."Nett_Price">a."Cost_Price"
group by 1,2
)
,
store_top_vol_product as (
select distinct *
from 
(
select distinct
a.*,
j."Material_Group_1_Code",
b."Store_Nett_Amount",
100*a."Store_Product_Nett_Amount"/b."Store_Nett_Amount" as "Store_Product_Nett_Amount_Percent",
SUM("Store_Product_Nett_Amount_Percent") OVER (PARTITION BY a."Store_Code", j."Material_Group_1_Code" ORDER BY "Store_Product_Nett_Amount_Percent" desc) AS "Store_Product_Nett_Amount_Percent_CumSum"
from store_product_summ a
left JOIN (SELECT * FROM "EDP_PROD"."PRES"."Dim_Sales_Org_Product"
QUALIFY ROW_NUMBER() OVER (PARTITION BY "Product_Code" ORDER BY "ETL_ROW_EFFECTIVE_DATE" desc)=1)  j
ON a."Product_Code" = RIGHT(j."Product_Code",8)
left join store_summ b
on a."Store_Code"=b."Store_Code"
and j."Material_Group_1_Code"=b."Material_Group_1_Code"
)
where "Store_Product_Nett_Amount_Percent_CumSum"<=80
)
,
store_product_pretrain_order_month_cnt as (
select 
"Store_Code",
"Product_Code",
count(distinct "Order_Month_Start_Date") "Order_Month_Cnt_PreTrain"
from (
select distinct
"Store_Code",
"Product_Code",
"Order_Month_Start_Date"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Product_Code" in (select distinct "Product_Code" from store_top_vol_product)
--and "Nett_Price">"Cost_Price"
and "Order_Date" >= date('2021-09-01') and "Order_Date"<=date('2022-08-31')
--"Order_Date" >= date('2019-10-01') and "Order_Date"<=date('2020-09-30')
)
group by 1,2
)
,
store_product_train_order_month_cnt as (
select 
"Store_Code",
"Product_Code",
count(distinct "Order_Month_Start_Date") "Order_Month_Cnt_Train"
from (
select distinct
"Store_Code",
"Product_Code",
"Order_Month_Start_Date"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA
where "Product_Code" in (select distinct "Product_Code" from store_top_vol_product)
--and "Nett_Price">"Cost_Price"
and "Order_Date">=date('2022-09-01') and "Order_Date"<=date('2023-08-31')
--"Order_Date">=date('2020-10-01') and "Order_Date"<=date('2023-09-30')
)
group by 1,2
)
,
scope as (
select distinct 
"Store_Code",
"Product_Code"
from 
(
select distinct
a.*,
b."Order_Month_Cnt_Train"
from store_product_pretrain_order_month_cnt a
join store_product_train_order_month_cnt b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
)
where "Order_Month_Cnt_PreTrain">=3 and "Order_Month_Cnt_Train">=3
--"Order_Month_Cnt_Train">=9
)
,
demand_grp_top as (
select distinct 
e."Demand_Group_Code",
e."Material_Group_1_Code",
e."Product_Code",
100*e."Product_Total_Nett_Sales_Amount"/f."Group_Total_Nett_Sales_Amount" as "Product_Nett_Sales_Amount_Percent",
SUM("Product_Nett_Sales_Amount_Percent") OVER (PARTITION BY e."Demand_Group_Code", e."Material_Group_1_Code" ORDER BY "Product_Nett_Sales_Amount_Percent" desc) AS "Product_Nett_Sales_Amount_Percent_CumSum"
from 
(select 
c."Demand_Group_Code",
j."Material_Group_1_Code",
right(d."Product_Code",8) "Product_Code",
greatest(sum(a."Nett_Sales_Amount"),0) "Product_Total_Nett_Sales_Amount"
from edp_prod.pres."Fact_Sales_Order" a
--left JOIN "EDP_PROD"."PRES"."Dim_Customer" c
--ON a."Sold_To_Customer_Key" = c."Customer_Key"
--and c."Distribution_Channel_Name"='WHOLESALE'
left join "EDP_PROD"."PRES"."Dim_Customer_Attribute" c
on a."Sold_To_Customer_Attribute_Key"=c."Customer_Attribute_Key"
JOIN "EDP_PROD"."PRES"."Dim_Product" d
ON a."Product_Key" = d."Product_Key"
and d."Product_Key">0
and UPPER(d."Product_Name") NOT LIKE '%COVID%'
JOIN (SELECT * FROM "EDP_PROD"."PRES"."Dim_Sales_Org_Product"
QUALIFY ROW_NUMBER() OVER (PARTITION BY "Product_Code" ORDER BY "ETL_ROW_EFFECTIVE_DATE" desc)=1)  j
ON d."Product_Code" = j."Product_Code" 
where Date(a."Order_Date_Key",'YYYYMMDD') >= date('2021-09-01') and Date(a."Order_Date_Key",'YYYYMMDD')<=date('2023-12-31')
group by 1,2,3) e
left join 
(select c."Demand_Group_Code",
j."Material_Group_1_Code",
greatest(sum(a."Nett_Sales_Amount"),0) "Group_Total_Nett_Sales_Amount"
from edp_prod.pres."Fact_Sales_Order" a
--JOIN "EDP_PROD"."PRES"."Dim_Customer" c
--ON a."Sold_To_Customer_Key" = c."Customer_Key"
--and c."Distribution_Channel_Name"='WHOLESALE'
left join "EDP_PROD"."PRES"."Dim_Customer_Attribute" c
on a."Sold_To_Customer_Attribute_Key"=c."Customer_Attribute_Key"
JOIN "EDP_PROD"."PRES"."Dim_Product" d
ON a."Product_Key" = d."Product_Key"
and d."Product_Key">0
and UPPER(d."Product_Name") NOT LIKE '%COVID%'
JOIN (SELECT * FROM "EDP_PROD"."PRES"."Dim_Sales_Org_Product"
QUALIFY ROW_NUMBER() OVER (PARTITION BY "Product_Code" ORDER BY "ETL_ROW_EFFECTIVE_DATE" desc)=1)  j
ON d."Product_Code" = j."Product_Code" 
where Date(a."Order_Date_Key",'YYYYMMDD') >= date('2021-09-01') and Date(a."Order_Date_Key",'YYYYMMDD')<=date('2023-12-31')
group by 1,2) f
on e."Demand_Group_Code"=f."Demand_Group_Code"
and e."Material_Group_1_Code"=f."Material_Group_1_Code"
and f."Group_Total_Nett_Sales_Amount">0
)
,
poc as (
select --distinct
a.*, j."Material_Group_1_Code"
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA a
JOIN (SELECT * FROM "EDP_PROD"."PRES"."Dim_Sales_Org_Product"
QUALIFY ROW_NUMBER() OVER (PARTITION BY "Product_Code" ORDER BY "ETL_ROW_EFFECTIVE_DATE" desc)=1)  j
ON a."Product_Code" = RIGHT(j."Product_Code",8) 
inner join edp_prod.pres."Dim_Product" b
on a."Product_Code"=right(b."Product_Code",8)
and b."Cross_Plant_Stock_Condition" not in ('DD','DS','IC','NW','RD','RS')
--join edp_prod.pres."Dim_Customer_Retail_Store" h
--ON a."Store_Code" = h."Store_Code"
--join edp_prod.pres."Dim_Customer" c
--on h."Site_Link_Code"=c."Site_Link_Code"
--and c."Distribution_Channel_Name"='WHOLESALE'
--join demand_grp_top g
--on c."Demand_Group_Code"=g."Demand_Group_Code"
--and j."Material_Group_1_Code"=g."Material_Group_1_Code"
--and a."Product_Code"=g."Product_Code"
--and g."Product_Nett_Sales_Amount_Percent_CumSum"<=80
where concat(a."Store_Code",'_',a."Product_Code") in (select distinct concat("Store_Code",'_',"Product_Code") from scope)
--and j."Material_Group_1_Code" in ('FOS','OTC')
and a."Product_Code" in (select distinct "Product_Code" from demand_grp_top where "Product_Nett_Sales_Amount_Percent_CumSum"<=80)
and a."Cost_Price">0 and a."Nett_Price">0 and a."Order_Quantity">=1
-- a."Nett_Price">a."Cost_Price"
)

select * from poc
where "Product_Code" in 
(select distinct "Product_Code" from 
(
select 
"Product_Code",
count(distinct "Store_Code") "Store_CNT"
from poc
group by 1
)
where "Store_CNT">=10
)
)
;