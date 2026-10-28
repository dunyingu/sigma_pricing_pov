import streamlit as st
import numpy as np
import decimal
import pandas as pd
import PricingData

@st.cache_resource
def init_connection():
    return PricingData.init_connection('sandpit')

@st.cache_data
def get_level3_categories():
    return PricingData.get_level3_categories(session)

@st.cache_data
def get_rev_gp(level_3_category, price_list):
    return PricingData.get_rev_gp(session, level_3_category, price_list)

def calc_impacts(rev_gp: pd.DataFrame, maxdiscount, maxpremium):
    rev_gp['Current Sigma Premium'] = rev_gp['Sigma Price'] - rev_gp['Competitor Price']
    rev_gp['Current Sigma Premium Pct'] = np.divide(rev_gp['Current Sigma Premium'] , rev_gp['Competitor Price']) 
    rev_gp['New Sigma Premium'] = np.minimum(np.maximum(maxdiscount, rev_gp['Current Sigma Premium']),maxpremium)
    rev_gp['New Sigma Price'] = np.round(rev_gp['Competitor Price'] + rev_gp['New Sigma Premium'],2)
    rev_gp['New Sigma Premium Pct'] = np.divide(rev_gp['New Sigma Premium'],  rev_gp['Competitor Price'])
    rev_gp['Quantity Impact'] = rev_gp['Quantity Base Unit'] * elasticity*(rev_gp['Current Sigma Premium Pct'] - rev_gp['New Sigma Premium Pct'])
    rev_gp['New Quantity'] = rev_gp['Quantity Base Unit'] + rev_gp['Quantity Impact']
    rev_gp['Total Impact'] = (rev_gp['New Quantity'] * rev_gp['New Sigma Price']) - rev_gp['Wholesale Nett Sales Revenue'].astype('float')
    return rev_gp

session = init_connection()
level3_categories = get_level3_categories()



with st.sidebar:
    category = st.selectbox('Product Category', level3_categories)
    pricelist = st.selectbox('Price List', ['','P1', 'P2', 'P3','P4'])
    maxdiscount, maxpremium = st.slider('Discount to competitors', min_value=-2.0, max_value=10.0, step=0.01, value=(-0.05, 5.0))
    elasticity = st.slider('Elasticity', min_value=0.0, max_value=2.0, step=0.01, value=0.05)

rev_gp = get_rev_gp(category, pricelist)
impacts = calc_impacts(rev_gp, maxdiscount, maxpremium)
st.metric('Total Impact', "${:,.0f}".format(impacts['Total Impact'].sum()))
st.bar_chart(impacts[impacts['Total Impact'] != 0], x='Product Name', y='Total Impact')
st.write(impacts)