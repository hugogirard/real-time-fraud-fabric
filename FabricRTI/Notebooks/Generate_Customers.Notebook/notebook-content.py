# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # 👤 Synthetic Customer Profile Generator
# 
# This notebook generates realistic synthetic customer profiles for the **Real-Time Intelligence Fraud Detection demo** on Microsoft Fabric.
# 
# **What it produces:**
# - **User Profiles** — Configurable number of synthetic cardholders with demographics, home location, and credit limits
# - **Entra ID–compatible identities** — UPN / email for each customer for identity correlation
# - **CSV export** — `customers_YYYY-MM-DD.csv` file for use by `Generate_Credit_Card_Transactions.ipynb` and `Create-EntraID-Customers.ps1`
# 
# **Customers are distributed across cities in the United States, Canada, Brazil, and Costa Rica.**

# MARKDOWN ********************

# ## 1. Install and Import Required Libraries

# CELL ********************

# %pip install faker --quiet

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
import numpy as np
import random
import os
from datetime import datetime
from faker import Faker
import warnings

warnings.filterwarnings("ignore")

fake = Faker()
Faker.seed(42)
np.random.seed(42)
random.seed(42)

print("Libraries imported successfully.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 2. Configuration
# 
# Set the number of users to generate and your Entra ID tenant domain.

# CELL ********************

# ── Configuration ──────────────────────────────────────────
NUM_USERS = 10                          # Number of synthetic cardholders to generate
RANDOM_SEED = 42

# Entra ID domain — used to generate user principal names (UPNs) for each customer
ENTRA_ID_DOMAIN = "<your-tenant>.onmicrosoft.com"   # Replace with your Azure AD tenant domain

print(f"Users to generate: {NUM_USERS}")
print(f"Entra ID domain: {ENTRA_ID_DOMAIN}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 3. Define City Reference Data
# 
# Cities across the Americas with approximate lat/lon, used for assigning home locations to customers.

# CELL ********************

# Major cities across the Americas with approximate lat/lon and country info
AMERICAS_CITIES = [
    # United States
    ("New York", "NY", "US", "10001", 40.7128, -74.0060),
    ("Los Angeles", "CA", "US", "90001", 34.0522, -118.2437),
    ("Chicago", "IL", "US", "60601", 41.8781, -87.6298),
    ("Houston", "TX", "US", "77001", 29.7604, -95.3698),
    ("Phoenix", "AZ", "US", "85001", 33.4484, -112.0740),
    ("Philadelphia", "PA", "US", "19101", 39.9526, -75.1652),
    ("San Antonio", "TX", "US", "78201", 29.4241, -98.4936),
    ("San Diego", "CA", "US", "92101", 32.7157, -117.1611),
    ("Dallas", "TX", "US", "75201", 32.7767, -96.7970),
    ("San Jose", "CA", "US", "95101", 37.3382, -121.8863),
    ("Austin", "TX", "US", "73301", 30.2672, -97.7431),
    ("Jacksonville", "FL", "US", "32099", 30.3322, -81.6557),
    ("Fort Worth", "TX", "US", "76101", 32.7555, -97.3308),
    ("Columbus", "OH", "US", "43085", 39.9612, -82.9988),
    ("Charlotte", "NC", "US", "28201", 35.2271, -80.8431),
    ("Indianapolis", "IN", "US", "46201", 39.7684, -86.1581),
    ("Seattle", "WA", "US", "98101", 47.6062, -122.3321),
    ("Denver", "CO", "US", "80201", 39.7392, -104.9903),
    ("Nashville", "TN", "US", "37201", 36.1627, -86.7816),
    ("Portland", "OR", "US", "97201", 45.5152, -122.6784),
    ("Miami", "FL", "US", "33101", 25.7617, -80.1918),
    ("Atlanta", "GA", "US", "30301", 33.7490, -84.3880),
    ("Boston", "MA", "US", "02101", 42.3601, -71.0589),
    ("Las Vegas", "NV", "US", "89101", 36.1699, -115.1398),
    ("Minneapolis", "MN", "US", "55401", 44.9778, -93.2650),
    # Canada
    ("Toronto", "ON", "CA", "M5A 1A1", 43.6532, -79.3832),
    ("Vancouver", "BC", "CA", "V5K 0A1", 49.2827, -123.1207),
    ("Montreal", "QC", "CA", "H2X 1Y4", 45.5017, -73.5673),
    ("Calgary", "AB", "CA", "T2P 1J9", 51.0447, -114.0719),
    ("Ottawa", "ON", "CA", "K1A 0A9", 45.4215, -75.6972),
    ("Edmonton", "AB", "CA", "T5J 0N3", 53.5461, -113.4938),
    ("Winnipeg", "MB", "CA", "R3C 0A1", 49.8951, -97.1384),
    ("Halifax", "NS", "CA", "B3H 0A1", 44.6488, -63.5752),
    # Brazil
    ("São Paulo", "SP", "BR", "01000-000", -23.5505, -46.6333),
    ("Rio de Janeiro", "RJ", "BR", "20000-000", -22.9068, -43.1729),
    ("Brasília", "DF", "BR", "70000-000", -15.7975, -47.8919),
    ("Salvador", "BA", "BR", "40000-000", -12.9714, -38.5124),
    ("Belo Horizonte", "MG", "BR", "30100-000", -19.9167, -43.9345),
    ("Curitiba", "PR", "BR", "80000-000", -25.4284, -49.2733),
    ("Recife", "PE", "BR", "50000-000", -8.0476, -34.8770),
    ("Porto Alegre", "RS", "BR", "90000-000", -30.0346, -51.2177),
    # Costa Rica
    ("San José", "SJ", "CR", "10101", 9.9281, -84.0907),
    ("Alajuela", "AL", "CR", "20101", 10.0162, -84.2115),
    ("Cartago", "CA", "CR", "30101", 9.8643, -83.9194),
    ("Heredia", "HE", "CR", "40101", 10.0024, -84.1165),
    ("Liberia", "GU", "CR", "50101", 10.6350, -85.4377),
]

# Country full names for display
COUNTRY_NAMES = {"US": "United States", "CA": "Canada", "BR": "Brazil", "CR": "Costa Rica"}

# Street names per country for realistic addresses
STREET_NAMES = {
    "US": ["Main St", "Oak Ave", "Maple Dr", "Elm St", "Park Blvd", "Cedar Ln", "Pine Rd", "Walnut St", "2nd Ave", "Broadway"],
    "CA": ["King St", "Queen St", "Yonge St", "Bay St", "Bloor St", "Dundas St", "Granville St", "Robson St", "Rideau St", "Jasper Ave"],
    "BR": ["Rua Augusta", "Av. Paulista", "Rua das Flores", "Av. Atlântica", "Rua da Consolação", "Av. Brasil", "Rua XV de Novembro"],
    "CR": ["Calle Central", "Avenida Segunda", "Calle 1", "Paseo Colón", "Av. 10", "Calle 42", "Ruta Nacional 1"],
}

print(f"Defined {len(AMERICAS_CITIES)} reference cities across {len(COUNTRY_NAMES)} countries.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 4. Generate Customer Profiles
# 
# Generate synthetic customer profiles with demographics, home location (lat/lon), full mailing addresses, credit limits, and **Entra ID–compatible identities** (UPN / email).
# 
# Each customer gets:
# - A unique `user_id` that links to every transaction
# - A `user_principal_name` (UPN) in the format `firstname.lastname@<your-tenant>.onmicrosoft.com` for Entra ID mapping
# - A realistic street address, city, state, postal code, and country

# CELL ********************

def generate_user_profiles(n_users):
    """Generate synthetic customer profiles with addresses and Entra ID–compatible identities."""
    profiles = []
    seen_upns = set()

    for i in range(n_users):
        city, state, country_code, postal_code, lat, lon = random.choice(AMERICAS_CITIES)
        # Add small random offset to lat/lon so users in same city aren't identical
        home_lat = lat + np.random.uniform(-0.15, 0.15)
        home_lon = lon + np.random.uniform(-0.15, 0.15)

        gender = random.choice(["M", "F"])
        first_name = fake.first_name_male() if gender == "M" else fake.first_name_female()
        last_name = fake.last_name()

        # Generate a unique UPN for Entra ID mapping
        base_upn = f"{first_name.lower()}.{last_name.lower()}@{ENTRA_ID_DOMAIN}"
        upn = base_upn
        suffix = 2
        while upn in seen_upns:
            upn = f"{first_name.lower()}.{last_name.lower()}{suffix}@{ENTRA_ID_DOMAIN}"
            suffix += 1
        seen_upns.add(upn)

        # Generate a realistic street address
        street_number = random.randint(100, 9999)
        street_name = random.choice(STREET_NAMES[country_code])
        street_address = f"{street_number} {street_name}"

        profile = {
            "user_id": f"U{i+1:04d}",
            "first_name": first_name,
            "last_name": last_name,
            "display_name": f"{first_name} {last_name}",
            "user_principal_name": upn,
            "email": upn,
            "age": np.random.randint(21, 72),
            "gender": gender,
            "street_address": street_address,
            "home_city": city,
            "home_state": state,
            "postal_code": postal_code,
            "country_code": country_code,
            "country": COUNTRY_NAMES[country_code],
            "home_lat": round(home_lat, 4),
            "home_lon": round(home_lon, 4),
            "credit_limit": round(random.choice([3000, 5000, 7500, 10000, 15000, 20000, 30000, 50000]), 2),
            "account_created": fake.date_between(start_date="-5y", end_date="-6m"),
        }
        profiles.append(profile)
    return pd.DataFrame(profiles)

users_df = generate_user_profiles(NUM_USERS)
print(f"Generated {len(users_df)} customer profiles.\n")
users_df[["user_id", "display_name", "user_principal_name", "street_address", "home_city", "home_state", "country", "postal_code"]]

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 5. Export Customers to CSV
# 
# Export the generated customer profiles to a CSV file named `customers_YYYY-MM-DD.csv` (using today's date). This file is used by:
# - `Generate_Credit_Card_Transactions.ipynb` — to generate transactions for these users
# - `Create-EntraID-Customers.ps1` — to provision Entra ID users
# - `Update-EntraID-Passwords.ps1` — to reset passwords

# CELL ********************

# Export with today's date in the filename
today_str = datetime.now().strftime("%Y-%m-%d")
notebook_dir = os.path.dirname(os.path.abspath("__file__"))
csv_filename = f"customers_{today_str}.csv"
csv_path = os.path.join(notebook_dir, csv_filename)

users_df.to_csv(csv_path, index=False)

print(f"✅ Exported {len(users_df)} customers to: {csv_path}")
print(f"\nFile: {csv_filename}")
print(f"Columns: {list(users_df.columns)}")
print(f"\n💡 Next steps:")
print(f"   1. Open Generate_Credit_Card_Transactions.ipynb — it will auto-detect this CSV")
print(f"   2. Run Create-EntraID-Customers.ps1 -CsvPath '{csv_filename}' to provision Entra ID users")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
