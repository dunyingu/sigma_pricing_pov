create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT AS 
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT_VW AS  
(select distinct 
a.* exclude "Insertion_Date",
round(ln(a."Monthly_Store_Level2_Sales_Quantity"+1),4) as "Monthly_Store_Level2_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Level3_Sales_Quantity"+1),4) as "Monthly_Store_Level3_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Level4_Sales_Quantity"+1),4) as "Monthly_Store_Level4_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Level5_Sales_Quantity"+1),4) as "Monthly_Store_Level5_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Total_Sales_Quantity"+1),4) as "Monthly_Store_Total_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Manufacturer_Sales_Quantity"+1),4) as "Monthly_Store_Manufacturer_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Manufacturer_Brand_Sales_Quantity"+1),4) as "Monthly_Store_Manufacturer_Brand_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Active_Ingredient_Sales_Quantity"+1),4) as "Monthly_Store_Active_Ingredient_Sales_Quantity_Log",
round(ln(a."Monthly_Store_PBS_Item_Code_Sales_Quantity"+1),4) as "Monthly_Store_PBS_Item_Code_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Product_Promotion_Sales_Quantity"+1),4) as "Monthly_Store_Product_Promotion_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Product_Sales_Quantity"+1),4) as "Monthly_Store_Product_Sales_Quantity_Log",
round(ln(a."Monthly_Store_Level2_Order_Quantity"+1),4) as "Monthly_Store_Level2_Order_Quantity_Log",
round(ln(a."Monthly_Store_Level3_Order_Quantity"+1),4) as "Monthly_Store_Level3_Order_Quantity_Log",
round(ln(a."Monthly_Store_Level4_Order_Quantity"+1),4) as "Monthly_Store_Level4_Order_Quantity_Log",
round(ln(a."Monthly_Store_Level5_Order_Quantity"+1),4) as "Monthly_Store_Level5_Order_Quantity_Log",
round(ln(a."Monthly_Store_Total_Order_Quantity"+1),4) as "Monthly_Store_Total_Order_Quantity_Log",
round(ln(a."Monthly_Store_Manufacturer_Order_Quantity"+1),4) as "Monthly_Store_Manufacturer_Order_Quantity_Log",
round(ln(a."Monthly_Store_Manufacturer_Brand_Order_Quantity"+1),4) as "Monthly_Store_Manufacturer_Brand_Order_Quantity_Log",
round(ln(a."Monthly_Store_Active_Ingredient_Order_Quantity"+1),4) as "Monthly_Store_Active_Ingredient_Order_Quantity_Log",
round(ln(a."Monthly_Store_PBS_Item_Code_Order_Quantity"+1),4) as "Monthly_Store_PBS_Item_Code_Order_Quantity_Log",
round(ln(a."Monthly_Wholesale_Promotion_Order_Quantity"+1),4) as "Monthly_Wholesale_Promotion_Order_Quantity_Log",
round(ln(a."Monthly_Sigma_Wholesale_Promotion_Order_Quantity"+1),4) as "Monthly_Sigma_Wholesale_Promotion_Order_Quantity_Log",
round(ln(a."Monthly_NonSigma_Wholesale_Promotion_Order_Quantity"+1),4) as "Monthly_NonSigma_Wholesale_Promotion_Order_Quantity_Log",
round(ln(a."Monthly_Store_Product_Avg_Quantity_per_Order"+1),4) as "Monthly_Store_Product_Avg_Quantity_per_Order_Log",
round(ln(a."Monthly_Store_Product_Sigma_Avg_Quantity_per_Order"+1),4) as "Monthly_Store_Product_Sigma_Avg_Quantity_per_Order_Log",
round(ln(a."Monthly_Store_Product_NonSigma_Avg_Quantity_per_Order"+1),4)as "Monthly_Store_Product_NonSigma_Avg_Quantity_per_Order_Log",
round(ln(greatest(a."Monthly_Sigma_Availability_Opportunity_Quantity",0)+1),4) as "Monthly_Sigma_Availability_Opportunity_Quantity_Log",
round(ln(a."Monthly_Store_Product_Sigma_Order_Quantity"+1),4) as "Monthly_Store_Product_Sigma_Order_Quantity_Log",
round(ln(a."Monthly_Store_Product_NonSigma_Order_Quantity"+1),4) as "Monthly_Store_Product_NonSigma_Order_Quantity_Log",
round(ln(a."Monthly_Store_Product_Order_Quantity"+1),4) as "Monthly_Store_Product_Order_Quantity_Log",
case when a."Monthly_Store_Product_Order_Quantity">0 then 1
     else 0 end as "Monthly_Store_Product_Order_Label",
b."Monthly_Avg_Cost_Price_I",
b."Monthly_Avg_Nett_Price_I",
b."Monthly_Sigma_Avg_Nett_Price_I",
b."Monthly_NonSigma_Avg_Nett_Price_I",
round(100*(a."Monthly_Avg_Start_Price"-b."Monthly_Avg_Nett_Price_I")/a."Monthly_Avg_Start_Price",2) "Monthly_Avg_Discount_I",
round(100*(b."Monthly_Avg_Nett_Price_I"-b."Monthly_Avg_Cost_Price_I")/b."Monthly_Avg_Cost_Price_I",2) "Monthly_Avg_Margin_I",
round(100*(b."Monthly_Sigma_Avg_Nett_Price_I"-b."Monthly_Avg_Cost_Price_I")/b."Monthly_Avg_Cost_Price_I",2) "Monthly_Sigma_Avg_Margin_I",
CASE WHEN b."Monthly_NonSigma_Avg_Nett_Price_I"<=0 AND b."Monthly_Sigma_Avg_Nett_Price_I"<=0 THEN 0
      WHEN b."Monthly_NonSigma_Avg_Nett_Price_I">0 AND b."Monthly_Sigma_Avg_Nett_Price_I"<=0 THEN 1000
      ELSE round(100*(b."Monthly_NonSigma_Avg_Nett_Price_I"/b."Monthly_Sigma_Avg_Nett_Price_I"-1),2) END AS "Monthly_Comp_Nett_Price_Index_I",
max("Monthly_Avg_Discount_I") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date" ROWS BETWEEN 12 preceding AND 1 preceding) "P12M_Max_Avg_Discount_I",
min("Monthly_Avg_Discount_I") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date" ROWS BETWEEN 12 preceding AND 1 preceding) "P12M_Min_Avg_Discount_I",
"Monthly_Avg_Discount_I"-"P12M_Max_Avg_Discount_I" as "Monthly_Diff_Max_Avg_Discount_I",
case when "Monthly_Avg_Discount_I"=0 and "P12M_Max_Avg_Discount_I"=0 then 0
      when "Monthly_Avg_Discount_I">0 and "P12M_Max_Avg_Discount_I"<=0 then 10000
      when "Monthly_Avg_Discount_I"<0 and "P12M_Max_Avg_Discount_I"=0 then -10000
      when "Monthly_Avg_Discount_I"<=0 and "P12M_Max_Avg_Discount_I"<0 then -round(100*"Monthly_Diff_Max_Avg_Discount_I"/"P12M_Max_Avg_Discount_I",1)
      else round(100*"Monthly_Diff_Max_Avg_Discount_I"/"P12M_Max_Avg_Discount_I",1) end as "Monthly_Index_Max_Avg_Discount_I",
"Monthly_Avg_Discount_I"-"P12M_Min_Avg_Discount_I" as "Monthly_Diff_Min_Avg_Discount_I",
case when "Monthly_Avg_Discount_I"=0 and "P12M_Min_Avg_Discount_I"=0 then 0
      when "Monthly_Avg_Discount_I">0 and "P12M_Min_Avg_Discount_I"<=0 then 10000
      when "Monthly_Avg_Discount_I"<0 and "P12M_Min_Avg_Discount_I"=0 then -10000
      when "Monthly_Avg_Discount_I"<=0 and "P12M_Min_Avg_Discount_I"<0 then -round(100*"Monthly_Diff_Min_Avg_Discount_I"/"P12M_Min_Avg_Discount_I",1)
      else round(100*"Monthly_Diff_Min_Avg_Discount_I"/"P12M_Min_Avg_Discount_I",1) end as "Monthly_Index_Min_Avg_Discount_I",
max("Monthly_Avg_Margin_I") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date" ROWS BETWEEN 12 preceding AND 1 preceding) "P12M_Max_Avg_Margin_I",
min("Monthly_Avg_Margin_I") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date" ROWS BETWEEN 12 preceding AND 1 preceding) "P12M_Min_Avg_Margin_I",
"Monthly_Avg_Margin_I"-"P12M_Max_Avg_Margin_I" as "Monthly_Diff_Max_Avg_Margin_I",
case when "Monthly_Avg_Margin_I"=0 and "P12M_Max_Avg_Margin_I"=0 then 0
      when "Monthly_Avg_Margin_I">0 and "P12M_Max_Avg_Margin_I"<=0 then 10000
      when "Monthly_Avg_Margin_I"<0 and "P12M_Max_Avg_Margin_I"=0 then -10000
      when "Monthly_Avg_Margin_I"<=0 and "P12M_Max_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Max_Avg_Margin_I"/"P12M_Max_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Max_Avg_Margin_I"/"P12M_Max_Avg_Margin_I",1) end as "Monthly_Index_Max_Avg_Margin_I",
"Monthly_Avg_Margin_I"-"P12M_Min_Avg_Margin_I" as "Monthly_Diff_Min_Avg_Margin_I",
case when "Monthly_Avg_Margin_I"=0 and "P12M_Min_Avg_Margin_I"=0 then 0
      when "Monthly_Avg_Margin_I">0 and "P12M_Min_Avg_Margin_I"<=0 then 10000
      when "Monthly_Avg_Margin_I"<0 and "P12M_Min_Avg_Margin_I"=0 then -10000
      when "Monthly_Avg_Margin_I"<=0 and "P12M_Min_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Min_Avg_Margin_I"/"P12M_Min_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Min_Avg_Margin_I"/"P12M_Min_Avg_Margin_I",1) end as "Monthly_Index_Min_Avg_Margin_I",
max("Monthly_Sigma_Avg_Margin_I") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date" ROWS BETWEEN 12 preceding AND 1 preceding) "P12M_Max_Sigma_Avg_Margin_I",
min("Monthly_Sigma_Avg_Margin_I") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date" ROWS BETWEEN 12 preceding AND 1 preceding) "P12M_Min_Sigma_Avg_Margin_I",
"Monthly_Sigma_Avg_Margin_I"-"P12M_Max_Sigma_Avg_Margin_I" as "Monthly_Diff_Max_Sigma_Avg_Margin_I",
case when "Monthly_Sigma_Avg_Margin_I"=0 and "P12M_Max_Sigma_Avg_Margin_I"=0 then 0
      when "Monthly_Sigma_Avg_Margin_I">0 and "P12M_Max_Sigma_Avg_Margin_I"<=0 then 10000
      when "Monthly_Sigma_Avg_Margin_I"<0 and "P12M_Max_Sigma_Avg_Margin_I"=0 then -10000
      when "Monthly_Sigma_Avg_Margin_I"<=0 and "P12M_Max_Sigma_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Max_Sigma_Avg_Margin_I"/"P12M_Max_Sigma_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Max_Sigma_Avg_Margin_I"/"P12M_Max_Sigma_Avg_Margin_I",1) end as "Monthly_Index_Max_Sigma_Avg_Margin_I",
"Monthly_Sigma_Avg_Margin_I"-"P12M_Min_Sigma_Avg_Margin_I" as "Monthly_Diff_Min_Sigma_Avg_Margin_I",
case when "Monthly_Sigma_Avg_Margin_I"=0 and "P12M_Min_Sigma_Avg_Margin_I"=0 then 0
      when "Monthly_Sigma_Avg_Margin_I">0 and "P12M_Min_Sigma_Avg_Margin_I"<=0 then 10000
      when "Monthly_Sigma_Avg_Margin_I"<0 and "P12M_Min_Sigma_Avg_Margin_I"=0 then -10000
      when "Monthly_Sigma_Avg_Margin_I"<=0 and "P12M_Min_Sigma_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Min_Sigma_Avg_Margin_I"/"P12M_Min_Sigma_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Min_Sigma_Avg_Margin_I"/"P12M_Min_Sigma_Avg_Margin_I",1) end as "Monthly_Index_Min_Sigma_Avg_Margin_I",
--nvl(c."Promo_Flag",0) "Wholesale_Promo_Flag", 
nvl(c."Promo_Cnt",0) "Wholesale_Promo_Cnt",
case when "Wholesale_Promo_Cnt">=1 then 1
     else 0 end as "Wholesale_Promo_Flag",
ifnull(c."Wholesale_Promo_End_Date_Max"-c."Wholesale_Promo_Start_Date_Min"+1,0) as "Wholesale_Promo_Days_Max", 
ifnull(c."Monthly_Wholesale_Promo_End_Date_Max"-c."Monthly_Wholesale_Promo_Start_Date_Min"+1,0) as "Monthly_Wholesale_Promo_Days_Max",
case when "Wholesale_Promo_Cnt">0 then "Wholesale_Promo_Days_Max"-(c."Monthly_Wholesale_Promo_End_Date_Max"-c."Wholesale_Promo_Start_Date_Min"+1)
     else -1 end as "Wholesale_Promo_Remaining_Days",
case when "Wholesale_Promo_Cnt">0 then round(100*"Wholesale_Promo_Remaining_Days"/"Wholesale_Promo_Days_Max",2)
     else -1 end as  "Wholesale_Promo_Remaining_Days_Portion",
ifnull(c."Promo_Minimum_Buy_Qty_Per_Order_Min",0) "Promo_Minimum_Buy_Qty_Per_Order", 
ifnull(c."Wholesale_Promo_Discount_Percentage_Avg",0) "Wholesale_Promo_Discount_Percentage_Avg", 
ifnull(c."Retail_Promo_End_Date_Max"-c."Retail_Promo_Start_Date_Min"+1,0) as "Retail_Promo_Days_Max", 
case when "Retail_Promo_Days_Max">0 then 1
     else 0 end as "Retail_Promo_Flag",
ifnull(c."Monthly_Retail_Promo_End_Date_Max"-c."Monthly_Retail_Promo_Start_Date_Min"+1,0) as "Monthly_Retail_Promo_Days_Max", 
case when "Retail_Promo_Days_Max">0 then "Retail_Promo_Days_Max"-(c."Monthly_Retail_Promo_End_Date_Max"-c."Retail_Promo_Start_Date_Min"+1)
     else -1 end as "Retail_Promo_Remaining_Days",
case when "Retail_Promo_Days_Max">0 then round(100*"Retail_Promo_Remaining_Days"/"Retail_Promo_Days_Max",2)
     else -1 end as "Retail_Promo_Remaining_Days_Portion",
ifnull(c."Retail_Promo_Discount_Percentage_Avg",0) "Retail_Promo_Discount_Percentage_Avg",
LEAD("Monthly_Wholesale_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date") "Next_Month_Wholesale_Promotion_Days",
Lag("Monthly_Wholesale_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code"  ORDER BY a."Month_Start_Date") "Previous_Month_Wholesale_Promotion_Days",
LEAD("Monthly_Retail_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date") "Next_Month_Retail_Promotion_Days",
Lag("Monthly_Retail_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code"  ORDER BY a."Month_Start_Date") "Previous_Month_Retail_Promotion_Days",
current_date() as "Insertion_Date"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
join BANNER_RETAIL_STORE_WHOLESALE_COST_NETT_PRICE_IMPUTE_SAP_NOSTRA b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
join BANNER_STORE_MONTHLY_PROMO_ORDER_BASE c
on a."Month_Start_Date"=c."Month_Start_Date"
and a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
)
;