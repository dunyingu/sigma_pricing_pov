CREATE OR REPLACE TABLE BANNER_RETAIL_STORE_WHOLESALE_COST_NETT_PRICE_IMPUTE_SAP_NOSTRA AS 
--CREATE OR REPLACE VIEW BANNER_RETAIL_STORE_WHOLESALE_COST_NETT_PRICE_IMPUTE_SAP_NOSTRA_VW AS 
(
with base as 
(select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
a."Monthly_Avg_Cost_Price",
--a."Monthly_Avg_Start_Price",
a."Monthly_Avg_Nett_Price",
a."Monthly_Sigma_Avg_Nett_Price",
a."Monthly_NonSigma_Avg_Nett_Price",
a."Monthly_Store_Product_Order_Quantity",
a."Monthly_Store_Product_Sigma_Order_Quantity",
a."Monthly_Store_Product_NonSigma_Order_Quantity",
a."Monthly_Wholesale_Promotion_Order_Quantity",
a."Monthly_Sigma_Wholesale_Promotion_Order_Quantity",
a."Monthly_NonSigma_Wholesale_Promotion_Order_Quantity",
case when b."Promo_Cnt">=1 then 1
     else 0 end as "Wholesale_Promo_Flag"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
join BANNER_STORE_MONTHLY_PROMO_ORDER_BASE b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
)
,
hist_dmnd_grp as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
case when b."Demand_Group_Code" is not null then b."Demand_Group_Code"
      when b."Demand_Group_Code" is null and upper(c."Demand_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then  c."Demand_Group_Code"
      else null end as "Demand_Group_Code",
case when b."Price_List_Type_Code" is not null then b."Price_List_Type_Code"
     when b."Price_List_Type_Code" is null and upper(c."Price_List_Type_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then  c."Price_List_Type_Code"
      else null end as "Price_List_Type_Code"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
left join 
(
select distinct
a."Month_Start_Date",
a."Store_Code",
case when upper(b."Demand_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then b."Demand_Group_Code"
      else null end as "Demand_Group_Code",
case when upper(b."Price_List_Type_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then b."Price_List_Type_Code"
      else null end as "Price_List_Type_Code",
a."Month_Start_Date" - b."Effective_Start_Date" as "Effective_Days"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
left join CORE.DIM_CUSTOMER_STORE_HIST b
ON a."Store_Code"=b."Store_Code" 
and a."Month_Start_Date">=b."Effective_Start_Date"
and a."Month_Start_Date"<b."Effective_End_Date"
QUALIFY Row_Number() OVER (PARTITION BY 
a."Month_Start_Date",
a."Store_Code"
--"Demand_Group_Code",
--"Price_List_Type_Code"
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
store_demand_group as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
c."Demand_Group_Code"
--c."Price_List_Type_Code"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
left join hist_dmnd_grp c
on a."Month_Start_Date"=c."Month_Start_Date"
and a."Store_Code"=c."Store_Code"
and c."Price_List_Type_Code" like 'P%'
qualify row_number() OVER (PARTITION BY a."Month_Start_Date",a."Store_Code" ORDER BY c."Price_List_Type_Code",c."Demand_Group_Code")=1
)
,
cost_price_base as (
select 
"Month_Start_Date",
"Product_Code",
--round(case when sum("Monthly_Store_Product_Order_Quantity")>0 then sum(ifnull("Monthly_Avg_Cost_Price"*"Monthly_Store_Product_Order_Quantity",0))/sum("Monthly_Store_Product_Order_Quantity")
 --    else null end,2) as "Product_Monthly_Avg_Cost_Price"
mode("Monthly_Avg_Cost_Price") as "Product_Monthly_Avg_Cost_Price"
--,mode("Monthly_Avg_Start_Price") as "Product_Monthly_Avg_Start_Price"
from base
group by all
)
,
demand_group_nett_price_base as (
select 
"Month_Start_Date",
"Demand_Group_Code",
--"Price_List_Type_Code"
"Product_Code",
"Wholesale_Promo_Flag" ,
round(case when sum("Monthly_Store_Product_Order_Quantity")>0 then sum(ifnull("Monthly_Avg_Nett_Price"*"Monthly_Store_Product_Order_Quantity",0))/sum("Monthly_Store_Product_Order_Quantity")
     else null end,2) as "Demand_Group_Monthly_Avg_Nett_Price",
round(case when sum("Monthly_Store_Product_Sigma_Order_Quantity")>0 then sum(ifnull("Monthly_Sigma_Avg_Nett_Price"*"Monthly_Store_Product_Sigma_Order_Quantity",0))/sum("Monthly_Store_Product_Sigma_Order_Quantity")
     else null end,2) as "Demand_Group_Monthly_Sigma_Avg_Nett_Price",
--case when "Wholesale_Promo_Flag" = 1 then round(case when sum("Monthly_Sigma_Wholesale_Promotion_Order_Quantity")>0 then sum(ifnull("Monthly_Sigma_Avg_Nett_Price"*"Monthly_Sigma_Wholesale_Promotion_Order_Quantity",0))/sum("Monthly_Sigma_Wholesale_Promotion_Order_Quantity")
  --   else null end,2) 
  --   else null end as "Demand_Group_Monthly_Sigma_Promotion_Avg_Nett_Price",
--case when "Wholesale_Promo_Flag" = 1 then round(case when sum("Monthly_Store_Product_Order_Quantity"-"Monthly_Sigma_Wholesale_Promotion_Order_Quantity")>0 then sum(ifnull("Monthly_Sigma_Avg_Nett_Price"*("Monthly_Store_Product_Order_Quantity"-"Monthly_Sigma_Wholesale_Promotion_Order_Quantity"),0))/sum("Monthly_Store_Product_Order_Quantity"-"Monthly_Sigma_Wholesale_Promotion_Order_Quantity")
  --   else null end,2) 
  --   else null end as "Demand_Group_Monthly_Sigma_NonPromotion_Avg_Nett_Price",
round(case when sum("Monthly_Store_Product_NonSigma_Order_Quantity")>0 then sum(ifnull("Monthly_NonSigma_Avg_Nett_Price"*"Monthly_Store_Product_NonSigma_Order_Quantity",0))/sum("Monthly_Store_Product_NonSigma_Order_Quantity")
     else null end,2) as "Demand_Group_Monthly_NonSigma_Avg_Nett_Price"
from 
(select distinct
a.*,
b."Demand_Group_Code"
--b."Price_List_Type_Code"
from base a
join store_demand_group b
on a."Store_Code"=b."Store_Code"
and a."Month_Start_Date"=b."Month_Start_Date")
group by all
)
,


cost_backward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Avg_Cost_Price" is not null then a."Monthly_Avg_Cost_Price"
     when a."Monthly_Avg_Cost_Price" is null and c."Monthly_Avg_Cost_Price_Impute" is not null then round("Monthly_Avg_Cost_Price_Impute",2)
     else null end as "Monthly_Avg_Cost_Price_I_B"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MAX_BY("Product_Monthly_Avg_Cost_Price", "Recent_Month_Start_Date") "Monthly_Avg_Cost_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
c."Month_Start_Date" "Recent_Month_Start_Date",
c."Product_Monthly_Avg_Cost_Price"
from base a
left join cost_price_base c
on --a."Store_Code"=c."Store_Code"
--and 
a."Product_Code"=c."Product_Code"
and c."Month_Start_Date"<=a."Month_Start_Date"
and c."Product_Monthly_Avg_Cost_Price" is not null
where a."Monthly_Avg_Cost_Price" is null
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,
cost_forward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Avg_Cost_Price" is not null then a."Monthly_Avg_Cost_Price"
     when a."Monthly_Avg_Cost_Price" is null and c."Monthly_Avg_Cost_Price_Impute" is not null then round("Monthly_Avg_Cost_Price_Impute",2)
     else null end as "Monthly_Avg_Cost_Price_I_F"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MIN_BY("Product_Monthly_Avg_Cost_Price", "Recent_Month_Start_Date") "Monthly_Avg_Cost_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
c."Month_Start_Date" "Recent_Month_Start_Date",
c."Product_Monthly_Avg_Cost_Price"
from base a
left join cost_price_base c
on --a."Store_Code"=c."Store_Code"
--and 
a."Product_Code"=c."Product_Code"
and c."Month_Start_Date">a."Month_Start_Date"
and c."Product_Monthly_Avg_Cost_Price" is not null
where a."Monthly_Avg_Cost_Price" is null
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,


/*
start_backward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Avg_Start_Price" is not null then a."Monthly_Avg_Start_Price"
     when a."Monthly_Avg_Start_Price" is null and c."Monthly_Avg_Start_Price_Impute" is not null then round("Monthly_Avg_Start_Price_Impute",2)
     else null end as "Monthly_Avg_Start_Price_I_B"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MAX_BY("Product_Monthly_Avg_Start_Price", "Recent_Month_Start_Date") "Monthly_Avg_Start_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
c."Month_Start_Date" "Recent_Month_Start_Date",
c."Product_Monthly_Avg_Start_Price"
from base a
left join cost_price_base c
on --a."Store_Code"=c."Store_Code"
--and 
a."Product_Code"=c."Product_Code"
and c."Month_Start_Date"<=a."Month_Start_Date"
and c."Product_Monthly_Avg_Start_Price" is not null
where a."Monthly_Avg_Start_Price" is null
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,
start_forward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Avg_Start_Price" is not null then a."Monthly_Avg_Start_Price"
     when a."Monthly_Avg_Start_Price" is null and c."Monthly_Avg_Start_Price_Impute" is not null then round("Monthly_Avg_Start_Price_Impute",2)
     else null end as "Monthly_Avg_Start_Price_I_F"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MIN_BY("Product_Monthly_Avg_Start_Price", "Recent_Month_Start_Date") "Monthly_Avg_Start_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
c."Month_Start_Date" "Recent_Month_Start_Date",
c."Product_Monthly_Avg_Start_Price"
from base a
left join cost_price_base c
on --a."Store_Code"=c."Store_Code"
--and 
a."Product_Code"=c."Product_Code"
and c."Month_Start_Date">a."Month_Start_Date"
and c."Product_Monthly_Avg_Start_Price" is not null
where a."Monthly_Avg_Start_Price" is null
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,
*/

nett_backward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Avg_Nett_Price" is not null then a."Monthly_Avg_Nett_Price"
     when a."Monthly_Avg_Nett_Price" is null and c."Monthly_Avg_Nett_Price_Impute" is not null then round(c."Monthly_Avg_Nett_Price_Impute",2)
     else null end as "Monthly_Avg_Nett_Price_I_B"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MAX_BY("Group_Monthly_Avg_Nett_Price", "Recent_Month_Start_Date") "Monthly_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
a."Wholesale_Promo_Flag",
--a."Monthly_Avg_Nett_Price",
c."Month_Start_Date" "Recent_Month_Start_Date",
median(c."Demand_Group_Monthly_Avg_Nett_Price") "Group_Monthly_Avg_Nett_Price"
from base a
join store_demand_group b
on a."Store_Code"=b."Store_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
left join demand_group_nett_price_base c
on b."Demand_Group_Code"=c."Demand_Group_Code"
and a."Product_Code"=c."Product_Code"
and a."Wholesale_Promo_Flag"=c."Wholesale_Promo_Flag"
and c."Month_Start_Date"<=a."Month_Start_Date"
and c."Demand_Group_Monthly_Avg_Nett_Price" is not null
where a."Monthly_Avg_Nett_Price" is null
group by all
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,
nett_forward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Avg_Nett_Price" is not null then a."Monthly_Avg_Nett_Price"
     when a."Monthly_Avg_Nett_Price" is null and c."Monthly_Avg_Nett_Price_Impute" is not null then round(c."Monthly_Avg_Nett_Price_Impute",2)
     else null end as "Monthly_Avg_Nett_Price_I_F"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MIN_BY("Group_Monthly_Avg_Nett_Price", "Recent_Month_Start_Date") "Monthly_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
a."Wholesale_Promo_Flag",
--a."Monthly_Avg_Nett_Price",
c."Month_Start_Date" "Recent_Month_Start_Date",
median(c."Demand_Group_Monthly_Avg_Nett_Price") "Group_Monthly_Avg_Nett_Price"
from base a
join store_demand_group b
on a."Store_Code"=b."Store_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
left join demand_group_nett_price_base c
on b."Demand_Group_Code"=c."Demand_Group_Code"
and a."Product_Code"=c."Product_Code"
and a."Wholesale_Promo_Flag"=c."Wholesale_Promo_Flag"
and c."Month_Start_Date">a."Month_Start_Date"
and c."Demand_Group_Monthly_Avg_Nett_Price" is not null
where a."Monthly_Avg_Nett_Price" is null
group by all
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,


sigma_nett_backward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Sigma_Avg_Nett_Price" is not null then a."Monthly_Sigma_Avg_Nett_Price"
     when a."Monthly_Sigma_Avg_Nett_Price" is null and c."Monthly_Sigma_Avg_Nett_Price_Impute" is not null then round(c."Monthly_Sigma_Avg_Nett_Price_Impute",2)
     else null end as "Monthly_Sigma_Avg_Nett_Price_I_B"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MAX_BY("Group_Monthly_Sigma_Avg_Nett_Price", "Recent_Month_Start_Date") "Monthly_Sigma_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
a."Wholesale_Promo_Flag",
--a."Monthly_Sigma_Avg_Nett_Price",
c."Month_Start_Date" "Recent_Month_Start_Date",
median(c."Demand_Group_Monthly_Sigma_Avg_Nett_Price") "Group_Monthly_Sigma_Avg_Nett_Price"
from base a
join store_demand_group b
on a."Store_Code"=b."Store_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
left join demand_group_nett_price_base c
on b."Demand_Group_Code"=c."Demand_Group_Code"
and a."Product_Code"=c."Product_Code"
and a."Wholesale_Promo_Flag"=c."Wholesale_Promo_Flag"
and c."Month_Start_Date"<=a."Month_Start_Date"
and c."Demand_Group_Monthly_Sigma_Avg_Nett_Price" is not null
where a."Monthly_Sigma_Avg_Nett_Price" is null
group by all
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,
sigma_nett_forward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_Sigma_Avg_Nett_Price" is not null then a."Monthly_Sigma_Avg_Nett_Price"
     when a."Monthly_Sigma_Avg_Nett_Price" is null and c."Monthly_Sigma_Avg_Nett_Price_Impute" is not null then round(c."Monthly_Sigma_Avg_Nett_Price_Impute",2)
     else null end as "Monthly_Sigma_Avg_Nett_Price_I_F"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MIN_BY("Group_Monthly_Sigma_Avg_Nett_Price", "Recent_Month_Start_Date") "Monthly_Sigma_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
a."Wholesale_Promo_Flag",
--a."Monthly_Sigma_Avg_Nett_Price",
c."Month_Start_Date" "Recent_Month_Start_Date",
median(c."Demand_Group_Monthly_Sigma_Avg_Nett_Price") "Group_Monthly_Sigma_Avg_Nett_Price"
from base a
join store_demand_group b
on a."Store_Code"=b."Store_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
left join demand_group_nett_price_base c
on b."Demand_Group_Code"=c."Demand_Group_Code"
and a."Product_Code"=c."Product_Code"
and a."Wholesale_Promo_Flag"=c."Wholesale_Promo_Flag"
and c."Month_Start_Date">a."Month_Start_Date"
and c."Demand_Group_Monthly_Sigma_Avg_Nett_Price" is not null
where a."Monthly_Sigma_Avg_Nett_Price" is null
group by all
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,



nonsigma_nett_backward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_NonSigma_Avg_Nett_Price" is not null then a."Monthly_NonSigma_Avg_Nett_Price"
     when a."Monthly_NonSigma_Avg_Nett_Price" is null and c."Monthly_NonSigma_Avg_Nett_Price_Impute" is not null then round(c."Monthly_NonSigma_Avg_Nett_Price_Impute",2)
     else null end as "Monthly_NonSigma_Avg_Nett_Price_I_B"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MAX_BY("Group_Monthly_NonSigma_Avg_Nett_Price", "Recent_Month_Start_Date") "Monthly_NonSigma_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
a."Wholesale_Promo_Flag",
--a."Monthly_NonSigma_Avg_Nett_Price",
c."Month_Start_Date" "Recent_Month_Start_Date",
median(c."Demand_Group_Monthly_NonSigma_Avg_Nett_Price") "Group_Monthly_NonSigma_Avg_Nett_Price"
from base a
join store_demand_group b
on a."Store_Code"=b."Store_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
left join demand_group_nett_price_base c
on b."Demand_Group_Code"=c."Demand_Group_Code"
and a."Product_Code"=c."Product_Code"
and a."Wholesale_Promo_Flag"=c."Wholesale_Promo_Flag"
and c."Month_Start_Date"<=a."Month_Start_Date"
and c."Demand_Group_Monthly_NonSigma_Avg_Nett_Price" is not null
where a."Monthly_NonSigma_Avg_Nett_Price" is null
group by all
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)
,
nonsigma_nett_forward_impute as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
case when a."Monthly_NonSigma_Avg_Nett_Price" is not null then a."Monthly_NonSigma_Avg_Nett_Price"
     when a."Monthly_NonSigma_Avg_Nett_Price" is null and c."Monthly_NonSigma_Avg_Nett_Price_Impute" is not null then round(c."Monthly_NonSigma_Avg_Nett_Price_Impute",2)
     else null end as "Monthly_NonSigma_Avg_Nett_Price_I_F"
from base a
left join
(
select 
"Month_Start_Date",
"Store_Code",
"Product_Code",
MIN_BY("Group_Monthly_NonSigma_Avg_Nett_Price", "Recent_Month_Start_Date") "Monthly_NonSigma_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Month_Start_Date",
a."Store_Code",
a."Product_Code",
a."Wholesale_Promo_Flag",
--a."Monthly_NonSigma_Avg_Nett_Price",
c."Month_Start_Date" "Recent_Month_Start_Date",
median(c."Demand_Group_Monthly_NonSigma_Avg_Nett_Price") "Group_Monthly_NonSigma_Avg_Nett_Price"
from base a
join store_demand_group b
on a."Store_Code"=b."Store_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
left join demand_group_nett_price_base c
on b."Demand_Group_Code"=c."Demand_Group_Code"
and a."Product_Code"=c."Product_Code"
and a."Wholesale_Promo_Flag"=c."Wholesale_Promo_Flag"
and c."Month_Start_Date">a."Month_Start_Date"
and c."Demand_Group_Monthly_NonSigma_Avg_Nett_Price" is not null
where a."Monthly_NonSigma_Avg_Nett_Price" is null
group by all
)
group by all
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
)


select distinct 
a.*,
case when a."Monthly_Avg_Cost_Price" is not null then a."Monthly_Avg_Cost_Price" 
     when a."Monthly_Avg_Cost_Price" is null and b."Monthly_Avg_Cost_Price_I_B" is not null then b."Monthly_Avg_Cost_Price_I_B"
     when a."Monthly_Avg_Cost_Price" is null and b."Monthly_Avg_Cost_Price_I_B" is null and c."Monthly_Avg_Cost_Price_I_F" is not null then c."Monthly_Avg_Cost_Price_I_F"
     else null end as "Monthly_Avg_Cost_Price_I",
case when a."Monthly_Avg_Nett_Price" is not null then a."Monthly_Avg_Nett_Price" 
     when a."Monthly_Avg_Nett_Price" is null and d."Monthly_Avg_Nett_Price_I_B" is not null then d."Monthly_Avg_Nett_Price_I_B"
     when a."Monthly_Avg_Nett_Price" is null and d."Monthly_Avg_Nett_Price_I_B" is null and e."Monthly_Avg_Nett_Price_I_F" is not null then e."Monthly_Avg_Nett_Price_I_F"
     else null end as "Monthly_Avg_Nett_Price_I",
case when a."Monthly_Sigma_Avg_Nett_Price" is not null then a."Monthly_Sigma_Avg_Nett_Price" 
     when a."Monthly_Sigma_Avg_Nett_Price" is null and f."Monthly_Sigma_Avg_Nett_Price_I_B" is not null then f."Monthly_Sigma_Avg_Nett_Price_I_B"
     when a."Monthly_Sigma_Avg_Nett_Price" is null and f."Monthly_Sigma_Avg_Nett_Price_I_B" is null and g."Monthly_Sigma_Avg_Nett_Price_I_F" is not null then g."Monthly_Sigma_Avg_Nett_Price_I_F"
     else null end as "Monthly_Sigma_Avg_Nett_Price_I",
case when a."Monthly_NonSigma_Avg_Nett_Price" is not null then a."Monthly_NonSigma_Avg_Nett_Price" 
     when a."Monthly_NonSigma_Avg_Nett_Price" is null and h."Monthly_NonSigma_Avg_Nett_Price_I_B" is not null then h."Monthly_NonSigma_Avg_Nett_Price_I_B"
     when a."Monthly_NonSigma_Avg_Nett_Price" is null and h."Monthly_NonSigma_Avg_Nett_Price_I_B" is null and i."Monthly_NonSigma_Avg_Nett_Price_I_F" is not null then i."Monthly_NonSigma_Avg_Nett_Price_I_F"
     else null end as "Monthly_NonSigma_Avg_Nett_Price_I",
current_date() as "Insertion_Date"
from base a
left join cost_backward_impute b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
left join cost_forward_impute c
on a."Month_Start_Date"=c."Month_Start_Date"
and a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
left join nett_backward_impute d
on a."Month_Start_Date"=d."Month_Start_Date"
and a."Store_Code"=d."Store_Code"
and a."Product_Code"=d."Product_Code"
left join nett_forward_impute e
on a."Month_Start_Date"=e."Month_Start_Date"
and a."Store_Code"=e."Store_Code"
and a."Product_Code"=e."Product_Code"
left join sigma_nett_backward_impute f
on a."Month_Start_Date"=f."Month_Start_Date"
and a."Store_Code"=f."Store_Code"
and a."Product_Code"=f."Product_Code"
left join sigma_nett_forward_impute g
on a."Month_Start_Date"=g."Month_Start_Date"
and a."Store_Code"=g."Store_Code"
and a."Product_Code"=g."Product_Code"
left join nonsigma_nett_backward_impute h
on a."Month_Start_Date"=h."Month_Start_Date"
and a."Store_Code"=h."Store_Code"
and a."Product_Code"=h."Product_Code"
left join nonsigma_nett_forward_impute i
on a."Month_Start_Date"=i."Month_Start_Date"
and a."Store_Code"=i."Store_Code"
and a."Product_Code"=i."Product_Code"
)
;