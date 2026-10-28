from snowflake.snowpark import Session
import SnowflakeConfig


def init_connection(environment):
    connection_params = SnowflakeConfig.connections[environment]['connection_params']
    return Session.builder.configs(connection_params).create()


def get_level3_categories(session):
    query = f'''
        Select distinct
        "Level 3 Name"
        From PRES."Dim_Product_VW"
        order by 1
    '''
    return session.sql(query).to_pandas()


def get_mg1_categories(session):
    query = f'''
        Select distinct
        "Material Group 1 Code"
        From PRES."Dim_Sales_Org_Product_Single_VW"
        order by 1
    '''
    return session.sql(query).to_pandas()


def get_yearmonth_categories(session):
    query = f'''
        Select distinct
        "Month Start Date"
        From WRK."COMP_PRICING"
        order by 1
    '''
    return session.sql(query).to_pandas()


def get_rev_gp(session, level_3_name, price_list):
    pl_where = ''
    if price_list != '':
        pl_where = f'''and "Price List Type Code" = '{price_list}' '''
    query = f'''
    SELECT
        "Level 3 Name",
        "Product Code",
        "Product Name",
        "Price List Type Code",
        sum("Wholesale Nett Sales Revenue") as "Wholesale Nett Sales Revenue",
        sum("Wholesale GP") as "Wholesale GP",
        sum("Quantity Base Unit") as "Quantity Base Unit",
        avg("SIGMA Median RPM Price") as "List Price",
        avg("Competitor Price") as "Competitor Price",
        avg("Sigma Price") as "Sigma Price"
    FROM WRK.BENCHMARKGP
    Where "Level 3 Name" = '{level_3_name}' {pl_where}
    group by 1,2,3,4
    Order by "Wholesale Nett Sales Revenue" desc
    '''
    return session.sql(query).to_pandas()


def get_streamlit_gp(session, level_3_name, price_list):
    pl_where = ''
    if price_list != '':
        pl_where = f'''and "Price List Type Code X" = '{price_list}' '''
    query = f'''
    SELECT
        *
    FROM WRK.HW_streamlit
    Where "Level_3_Name" = '{level_3_name}' {pl_where}
    ORDER BY "Product Code", "Month Start Date", "Wholesale_Purchasers"
    '''
    return session.sql(query).to_pandas()


def get_changeimpact_cents(session, level_3_name, price_list, mg1, yearmonth, minpremium, maxpremium, Competitor_Discount):
    yearmonth_where = f'''and "Month Start Date" IN '{yearmonth}' '''
    yearmonth_wherenis = f'''"Month Start Date" IN '{yearmonth}' '''
    pl_where = ''
    if Competitor_Discount:
        if price_list != '' & mg1 != '':
            pl_where = f'''and "Price List Type Code X" = '{price_list}' and "Material Group 1 Code" = '{mg1}' '''
        elif price_list != '' & mg1 == '':
            pl_where = f'''and "Price List Type Code X" = '{price_list}' '''
        elif price_list == '' & mg1 != '':
            pl_where = f'''and "Material Group 1 Code" = '{mg1}' '''
        query = f'''
        SELECT product_price.*,
        ({Competitor_Discount}) - "Competitive Premium" AS "Price Change Cents",
        DIV0({Competitor_Discount}, "Sigma Price") - "Competitive Premium %" AS "Price Change %",
        DIV0("Price Change Cents", "Sigma Price") AS "Perc Increase On Price",
        pivRev."'P1'" AS "P1 Revenue",
        pivRev."'P1'" * "Perc Increase On Price" AS "P1 Impact",
        pivRev."'P2'" AS "P2 Revenue",
        pivRev."'P3'" AS "P3 Revenue",
        pivRev."'P4'" AS "P4 Revenue"    
        FROM
        (
        Select 
        A.*,
        B.* exclude "Product Code",
        SOP.* exclude "Product",
        "Sigma1 Median List Price" - "COMP Min RPM Price" as "List Premium",
        Least(-"List Premium", -"Competitive Premium") - 0.01 as "Price Change", 
        "Sigma1 Median List Price" + "Price Change" as "New Price",
        y."Rank 1 Comp Price",
        y."Rank 2 Comp Price",
        y."Rank 3 Comp Price"
        from (
        Select "Product Code", "Product Name", max("COMP Min RPM Price") as "COMP Min RPM Price", max("SIGMA1 Min RPM Price") as "Sigma1 Median List Price"
        From WRK.COMP_PRICING where "Month Start Date" = '2023-04-01 00:00:00'
        group by 1,2) A
        LEFT join (
        Select "Product Code", avg("Sigma Price") as "Sigma Price", 
        avg("Competitor Price") as "Competitor Price", avg("Competitive Premium") as "Competitive Premium",
        avg("Competitive Premium %") as "Competitive Premium %"
        From WRK.COMP_PRICING z
        where {yearmonth_wherenis}
        group by 1
        ) B
        on A."Product Code" = B."Product Code"
        left join (Select "Product", "Material Group 1 Code" from Pres."Dim_Sales_Org_Product_Single_VW" where "Sales Organisation" = '1010' 
        qualify row_number() over (Partition by "Product" order by "Material Group 1 Code" desc nulls last) = 1) SOP
        on SOP."Product" = A."Product Code"
        LEFT JOIN (SELECT * FROM WRK.RANK_PRICING_COMP WHERE "Month Start Date" = '2023-04-01') y
            ON A."Product Code" = y."Product Code"
        LEFT JOIN (SELECT a."Product Code", a."Level 2 Name", a."Level 3 Name" FROM PRES."Dim_Product_VW" a ) dp
            ON A."Product Code" = dp."Product Code"
        Where "Level 3 Name" = '{level_3_name}' {pl_where}
        ORDER BY "Product Code"
        ) product_price
        LEFT JOIN 
        (
        SELECT *
        FROM (Select "Price List Type Code", "Product Code" AS PRODUCT,"Product Name", "Wholesale Nett Sales Revenue"
            FROM WRK.BENCHMARKGP
            Where {yearmonth_wherenis}
            )
            PIVOT(sum("Wholesale Nett Sales Revenue") FOR "Price List Type Code" in ('P1', 'P2', 'P3', 'P4'))
                as p
        ) pivRev
            ON product_price."Product Code" = pivRev."PRODUCT"
        WHERE "Competitive Premium" >= {minpremium} AND "Competitive Premium" <= {maxpremium}
        '''
        return session.sql(query).to_pandas()




def get_changeimpact_perc(session, level_3_name, price_list, mg1, yearmonth, minpremium, maxpremium, Competitor_Discount):
    yearmonth_where = f'''and "Month Start Date" = '{yearmonth}' '''
    yearmonth_wherenis = f'''"Month Start Date" = '{yearmonth}' '''
    pl_where = ''
    if Competitor_Discount != '':
        if price_list != '':
            if mg1 != '':
                pl_where = f'''and "Price List Type Code X" = '{price_list}' and "Material Group 1 Code" = '{mg1}' '''
            elif mg1 == '':
                pl_where = f'''and "Price List Type Code X" = '{price_list}' '''
        elif price_list == '':
            pl_where = f'''and "Material Group 1 Code" = '{mg1}' '''
        query = f'''
        SELECT product_price.*,
        ({Competitor_Discount}*"Sigma Price") - "Competitive Premium" AS "Price Change Cents",
        {Competitor_Discount} - "Competitive Premium %" AS "Price Change %",
        DIV0("Price Change Cents", "Sigma Price") AS "Perc Increase On Price",
        pivRev."'P1'" AS "P1 Revenue",
        pivRev."'P1'" * "Perc Increase On Price" AS "P1 Impact",
        pivRev."'P2'" AS "P2 Revenue",
        pivRev."'P3'" AS "P3 Revenue",
        pivRev."'P4'" AS "P4 Revenue"    
        FROM
        (
        Select 
        A.*,
        B.* exclude "Product Code",
        SOP.* exclude "Product",
        "Sigma1 Median List Price" - "COMP Min RPM Price" as "List Premium",
        Least(-"List Premium", -"Competitive Premium") - 0.01 as "Price Change", 
        "Sigma1 Median List Price" + "Price Change" as "New Price",
        y."Rank 1 Comp Price",
        y."Rank 2 Comp Price",
        y."Rank 3 Comp Price"
        from (
        Select "Product Code", "Product Name", max("COMP Min RPM Price") as "COMP Min RPM Price", max("SIGMA1 Min RPM Price") as "Sigma1 Median List Price"
        From WRK.COMP_PRICING where "Month Start Date" = '2023-04-01 00:00:00'
        group by 1,2) A
        LEFT join (
        Select "Product Code", avg("Sigma Price") as "Sigma Price", 
        avg("Competitor Price") as "Competitor Price", avg("Competitive Premium") as "Competitive Premium",
        avg("Competitive Premium %") as "Competitive Premium %"
        From WRK.COMP_PRICING z
        where {yearmonth_wherenis}
        group by 1
        ) B
        on A."Product Code" = B."Product Code"
        left join (Select "Product", "Material Group 1 Code" from Pres."Dim_Sales_Org_Product_Single_VW" where "Sales Organisation" = '1010' 
        qualify row_number() over (Partition by "Product" order by "Material Group 1 Code" desc nulls last) = 1) SOP
        on SOP."Product" = A."Product Code"
        LEFT JOIN (SELECT * FROM WRK.RANK_PRICING_COMP WHERE "Month Start Date" = '2023-04-01') y
            ON A."Product Code" = y."Product Code"
        LEFT JOIN (SELECT a."Product Code", a."Level 2 Name", a."Level 3 Name" FROM PRES."Dim_Product_VW" a ) dp
            ON A."Product Code" = dp."Product Code"
        Where "Level 3 Name" = '{level_3_name}' {pl_where}
        ORDER BY "Product Code"
        ) product_price
        LEFT JOIN 
        (
        SELECT *
        FROM (Select "Price List Type Code", "Product Code" AS PRODUCT,"Product Name", "Wholesale Nett Sales Revenue"
            FROM WRK.BENCHMARKGP
            Where {yearmonth_wherenis}
            )
            PIVOT(sum("Wholesale Nett Sales Revenue") FOR "Price List Type Code" in ('P1', 'P2', 'P3', 'P4'))
                as p
        ) pivRev
            ON product_price."Product Code" = pivRev."PRODUCT"
        WHERE "Competitive Premium %" >= {minpremium} AND "Competitive Premium %" <= {maxpremium}
        '''
        print(query)
        return session.sql(query).to_pandas()