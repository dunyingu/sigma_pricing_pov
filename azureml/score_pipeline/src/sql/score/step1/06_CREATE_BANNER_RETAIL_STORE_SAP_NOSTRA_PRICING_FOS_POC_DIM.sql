create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM as 
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM_VW as
(
select distinct 
a."Store_Code", b."Site_Link_Code", 
b."Store_Name", b."Banner_Group_Name", 
b."State_Code",
--c."Demand_Group_Name",
--c."Customer_Name",
a."Product_Code",
d."Product_Name",d."Level_1_Name",d."Level_2_Name",d."Level_3_Name",d."Level_4_Name",d."Level_5_Name"
,d."KVI_Flag"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG_PERM a
join edp_prod.pres."Dim_Customer_Retail_Store" b
on a."Store_Code"=b."Store_Code"
join edp_prod.pres."Dim_Customer" c
on b."Site_Link_Code" = c."Site_Link_Code"
and c."Distribution_Channel_Name"='WHOLESALE'
join EDP_PROD.PRES."Dim_Product" d
on a."Product_Code"=right(d."Product_Code",8)
)
;
