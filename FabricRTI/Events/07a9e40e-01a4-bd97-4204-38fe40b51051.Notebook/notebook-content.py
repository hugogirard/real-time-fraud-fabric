# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   }
# META }

# MARKDOWN ********************

# # 🏦 Credit Card Fraud Detection - Synthetic Data Generator
# 
# This notebook generates realistic synthetic credit card transaction data for a **Real-Time Intelligence Fraud Detection demo** on Microsoft Fabric.
# 
# **What it produces:**
# - **User Profiles** — 50 synthetic cardholders with demographics, home location, and credit limits
# - **Transactions** — ~10,000+ credit card transactions compressed into a 30-minute real-time stream
# - **Fraud Labels** — ~3-5% of transactions are fraudulent with realistic anomaly patterns
# - **Derived Features** — Distance from home, rolling averages, velocity features, and more
# 
# **Fraud patterns injected:**
# - Unusually high transaction amounts
# - Transactions far from the user's home city
# - Rapid-fire successive transactions
# - Purchases at unusual hours (2–5 AM)
# - Uncommon merchant categories for the user
# 
# **Output:** Transactions are streamed in real time to a Fabric **Eventstream** via a Custom App source (Event Hub endpoint), simulating 30 minutes of live card activity for Real-Time Intelligence dashboards and KQL queries.


# MARKDOWN ********************

# ## 1. Install and Import Required Libraries
# 
# Install the `Faker` library for generating realistic names and addresses, then import all required packages.
# Install `Azure Eventhub` for RTI ingestion.
# install `Kusto` Data for ingestion.

# CELL ********************

%pip install --upgrade pip --quiet
%pip install faker --quiet
%pip install azure-eventhub --quiet
%pip install azure-kusto-data azure-kusto-ingest --quiet

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
import numpy as np
import random
import uuid
from datetime import datetime, timedelta
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

# ## 2. Define Configuration Parameters
# 
# Set up all configurable parameters: number of users, date range, fraud ratio, and transaction volume.

# CELL ********************

# ── Configuration ──────────────────────────────────────────
NUM_USERS = 10                          # Number of synthetic cardholders
START_DATE = datetime(2025, 1, 1)       # Transaction window start
END_DATE = datetime(2025, 6, 30)        # Transaction window end
FRAUD_RATIO = 0.04                      # Target ~4% fraud rate
AVG_TXN_PER_USER_PER_DAY = 2            # Average daily transactions per user
RANDOM_SEED = 42

# Entra ID domain — used to generate user principal names (UPNs) for each customer
ENTRA_ID_DOMAIN = "MngEnvMCAP530541.onmicrosoft.com"   # Replace with your Azure AD tenant domain

# Derived
TOTAL_DAYS = (END_DATE - START_DATE).days
ESTIMATED_TOTAL_TXN = int(NUM_USERS * AVG_TXN_PER_USER_PER_DAY * TOTAL_DAYS)

print(f"Users: {NUM_USERS}")
print(f"Date range: {START_DATE.date()} → {END_DATE.date()} ({TOTAL_DAYS} days)")
print(f"Fraud ratio: {FRAUD_RATIO:.0%}")
print(f"Estimated transactions: ~{ESTIMATED_TOTAL_TXN:,}")
print(f"Entra ID domain: {ENTRA_ID_DOMAIN}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 3. Create Synthetic Customer Profiles
# 
# Generate 10 realistic customer profiles with demographics, home location (lat/lon), full mailing addresses, credit limits, and **Entra ID–compatible identities** (UPN / email). Customers are distributed across cities in the **United States, Canada, Brazil, and Costa Rica**.
# 
# Each customer gets:
# - A unique `user_id` that links to every transaction
# - A `user_principal_name` (UPN) in the format `firstname.lastname@MngEnvMCAP530541.onmicrosoft.com` for Entra ID mapping
# - A realistic street address, city, state, postal code, and country

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

# Dummy street names per country for realistic addresses
STREET_NAMES = {
    "US": ["Main St", "Oak Ave", "Maple Dr", "Elm St", "Park Blvd", "Cedar Ln", "Pine Rd", "Walnut St", "2nd Ave", "Broadway"],
    "CA": ["King St", "Queen St", "Yonge St", "Bay St", "Bloor St", "Dundas St", "Granville St", "Robson St", "Rideau St", "Jasper Ave"],
    "BR": ["Rua Augusta", "Av. Paulista", "Rua das Flores", "Av. Atlântica", "Rua da Consolação", "Av. Brasil", "Rua XV de Novembro"],
    "CR": ["Calle Central", "Avenida Segunda", "Calle 1", "Paseo Colón", "Av. 10", "Calle 42", "Ruta Nacional 1"],
}

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

# ## 4. Define Merchant Categories and Transaction Patterns
# 
# Each merchant category has a list of realistic merchant names, typical amount ranges, and frequency weights that control how often a user shops there.

# CELL ********************

MERCHANT_CATEGORIES = {
    "grocery": {
        "merchants": ["Walmart", "Kroger", "Whole Foods", "Trader Joe's", "Safeway", "Aldi", "Costco", "Publix"],
        "amount_range": (8, 180),
        "weight": 0.25,
    },
    "gas_station": {
        "merchants": ["Shell", "BP", "Chevron", "ExxonMobil", "Speedway", "Circle K", "QuikTrip"],
        "amount_range": (15, 75),
        "weight": 0.12,
    },
    "restaurant": {
        "merchants": ["McDonald's", "Starbucks", "Chipotle", "Olive Garden", "Applebee's", "Panera Bread", "Chick-fil-A", "Subway", "Domino's"],
        "amount_range": (5, 95),
        "weight": 0.20,
    },
    "online_shopping": {
        "merchants": ["Amazon", "eBay", "Etsy", "Target.com", "Best Buy Online", "Wayfair", "Zappos"],
        "amount_range": (10, 350),
        "weight": 0.15,
    },
    "entertainment": {
        "merchants": ["Netflix", "Spotify", "AMC Theatres", "Ticketmaster", "Steam", "Xbox Store", "PlayStation Store"],
        "amount_range": (5, 120),
        "weight": 0.08,
    },
    "travel": {
        "merchants": ["Delta Airlines", "United Airlines", "Marriott", "Hilton", "Airbnb", "Hertz", "Enterprise"],
        "amount_range": (50, 800),
        "weight": 0.05,
    },
    "health": {
        "merchants": ["CVS Pharmacy", "Walgreens", "Rite Aid", "GNC", "Planet Fitness", "LA Fitness"],
        "amount_range": (8, 150),
        "weight": 0.08,
    },
    "utilities": {
        "merchants": ["AT&T", "Verizon", "Comcast", "Duke Energy", "State Farm", "Allstate"],
        "amount_range": (40, 250),
        "weight": 0.05,
    },
    "clothing": {
        "merchants": ["Nike", "H&M", "Zara", "Nordstrom", "Gap", "Old Navy", "Macy's", "TJ Maxx"],
        "amount_range": (15, 300),
        "weight": 0.02,
    },
}

# Hour-of-day weights for normal spending behavior (higher = more likely)
NORMAL_HOUR_WEIGHTS = {
    0: 0.01, 1: 0.005, 2: 0.002, 3: 0.002, 4: 0.003, 5: 0.01,
    6: 0.03, 7: 0.06, 8: 0.08, 9: 0.07, 10: 0.07, 11: 0.08,
    12: 0.10, 13: 0.08, 14: 0.06, 15: 0.06, 16: 0.05, 17: 0.07,
    18: 0.08, 19: 0.06, 20: 0.04, 21: 0.03, 22: 0.02, 23: 0.01,
}

categories = list(MERCHANT_CATEGORIES.keys())
cat_weights = [MERCHANT_CATEGORIES[c]["weight"] for c in categories]
hours = list(NORMAL_HOUR_WEIGHTS.keys())
hour_weights = list(NORMAL_HOUR_WEIGHTS.values())

print(f"Defined {len(MERCHANT_CATEGORIES)} merchant categories with {sum(len(v['merchants']) for v in MERCHANT_CATEGORIES.values())} merchants total.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 5. Generate Normal Transaction Functions
# 
# Legitimate transactions follow realistic patterns: reasonable amounts per category, locations near the user's home, typical daytime hours, and amounts within credit limits.

# CELL ********************

def generate_normal_transaction(user, txn_date):
    """Generate a single legitimate transaction for a user on a given date."""
    # Pick a merchant category based on weights
    category = random.choices(categories, weights=cat_weights, k=1)[0]
    cat_info = MERCHANT_CATEGORIES[category]
    merchant = random.choice(cat_info["merchants"])

    # Amount within category's typical range (log-normal for realistic skew)
    low, high = cat_info["amount_range"]
    mu = np.log((low + high) / 2)
    sigma = 0.5
    amount = np.clip(np.random.lognormal(mu, sigma), low, min(high, user["credit_limit"]))
    amount = round(amount, 2)

    # Time of day — weighted toward business/daytime hours
    hour = random.choices(hours, weights=hour_weights, k=1)[0]
    minute = random.randint(0, 59)
    second = random.randint(0, 59)
    timestamp = txn_date.replace(hour=hour, minute=minute, second=second)

    # Location near user's home (within ~30 miles)
    merch_lat = user["home_lat"] + np.random.uniform(-0.3, 0.3)
    merch_lon = user["home_lon"] + np.random.uniform(-0.3, 0.3)

    # Pick a merchant city (usually same as home)
    if random.random() < 0.85:
        merch_city = user["home_city"]
        merch_state = user["home_state"]
    else:
        # Occasional nearby-city transaction
        city_info = random.choice(AMERICAS_CITIES)
        merch_city, merch_state = city_info[0], city_info[1]
        merch_lat = city_info[4] + np.random.uniform(-0.1, 0.1)
        merch_lon = city_info[5] + np.random.uniform(-0.1, 0.1)

    return {
        "transaction_id": str(uuid.uuid4()),
        "user_id": user["user_id"],
        "timestamp": timestamp,
        "amount": amount,
        "merchant_name": merchant,
        "merchant_category": category,
        "merchant_city": merch_city,
        "merchant_state": merch_state,
        "merchant_lat": round(merch_lat, 4),
        "merchant_lon": round(merch_lon, 4),
        "is_fraud": 0,
        "fraud_type": None,
    }

print("Normal transaction generator ready.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 6. Generate Fraudulent Transaction Functions
# 
# Fraudulent transactions exhibit anomalous patterns:
# - **high_amount** — Amounts significantly above the user's normal spending
# - **foreign_location** — Transactions far from the user's home city
# - **rapid_fire** — Multiple transactions within minutes
# - **odd_hours** — Purchases between 2–5 AM
# - **unusual_category** — High-value purchases in uncommon categories (e.g., electronics, jewelry)

# CELL ********************

# Foreign cities for geo-based fraud
FOREIGN_CITIES = [
    ("Lagos", "Nigeria", 6.5244, 3.3792),
    ("Moscow", "Russia", 55.7558, 37.6173),
    ("São Paulo", "Brazil", -23.5505, -46.6333),
    ("Bucharest", "Romania", 44.4268, 26.1025),
    ("Bangkok", "Thailand", 13.7563, 100.5018),
    ("London", "UK", 51.5074, -0.1278),
    ("Tokyo", "Japan", 35.6762, 139.6503),
    ("Mumbai", "India", 19.0760, 72.8777),
]

FRAUD_TYPES = ["high_amount", "foreign_location", "rapid_fire", "odd_hours", "unusual_category"]

def generate_fraud_transaction(user, txn_date, fraud_type=None):
    """Generate a single fraudulent transaction with a specific anomaly pattern."""
    if fraud_type is None:
        fraud_type = random.choice(FRAUD_TYPES)

    # Start from a normal transaction and modify it
    txn = generate_normal_transaction(user, txn_date)
    txn["is_fraud"] = 1
    txn["fraud_type"] = fraud_type
    txn["transaction_id"] = str(uuid.uuid4())

    if fraud_type == "high_amount":
        # Amount 3x–10x the category's typical max
        cat_info = MERCHANT_CATEGORIES[txn["merchant_category"]]
        multiplier = np.random.uniform(3, 10)
        txn["amount"] = round(cat_info["amount_range"][1] * multiplier, 2)

    elif fraud_type == "foreign_location":
        # Transaction from a foreign country
        city, country, lat, lon = random.choice(FOREIGN_CITIES)
        txn["merchant_city"] = city
        txn["merchant_state"] = country
        txn["merchant_lat"] = round(lat + np.random.uniform(-0.1, 0.1), 4)
        txn["merchant_lon"] = round(lon + np.random.uniform(-0.1, 0.1), 4)
        txn["amount"] = round(np.random.uniform(200, 2000), 2)

    elif fraud_type == "rapid_fire":
        # Transaction at an unusual time, mimicking card-testing
        txn["amount"] = round(np.random.uniform(1, 20), 2)
        base_hour = random.randint(1, 4)
        txn["timestamp"] = txn_date.replace(
            hour=base_hour,
            minute=random.randint(0, 10),
            second=random.randint(0, 59),
        )

    elif fraud_type == "odd_hours":
        # Large purchase between 2–5 AM
        hour = random.randint(2, 4)
        txn["timestamp"] = txn_date.replace(hour=hour, minute=random.randint(0, 59))
        txn["amount"] = round(np.random.uniform(150, 1500), 2)

    elif fraud_type == "unusual_category":
        # High-value purchase in an uncommon category
        txn["merchant_category"] = random.choice(["travel", "online_shopping", "clothing"])
        txn["merchant_name"] = random.choice(["Luxury Watches Inc", "Diamond Exchange", "Electronics Mega", "Gold Dealers Co"])
        txn["amount"] = round(np.random.uniform(500, 5000), 2)

    return txn

print("Fraud transaction generator ready.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 7. Generate Transactions for All Users
# 
# Loop through every user profile and generate a mix of normal and fraudulent transactions across the full date range. Uses a Poisson distribution for daily transaction counts to create natural variation.

# CELL ********************

all_transactions = []

for _, user in users_df.iterrows():
    user_dict = user.to_dict()
    
    # Determine number of fraud transactions for this user
    user_total_normal = int(np.random.poisson(AVG_TXN_PER_USER_PER_DAY * TOTAL_DAYS))
    user_total_fraud = max(1, int(user_total_normal * FRAUD_RATIO))

    # Generate normal transactions spread across the date range
    for _ in range(user_total_normal):
        random_day = START_DATE + timedelta(days=random.randint(0, TOTAL_DAYS - 1))
        txn = generate_normal_transaction(user_dict, random_day)
        all_transactions.append(txn)

    # Generate fraud transactions (clustered in random periods)
    fraud_days = sorted(random.sample(range(TOTAL_DAYS), min(user_total_fraud, TOTAL_DAYS)))
    for day_offset in fraud_days:
        fraud_date = START_DATE + timedelta(days=day_offset)
        fraud_type = random.choice(FRAUD_TYPES)
        txn = generate_fraud_transaction(user_dict, fraud_date, fraud_type)
        all_transactions.append(txn)
        
        # For rapid_fire fraud, add 2-4 extra quick transactions
        if fraud_type == "rapid_fire":
            for _ in range(random.randint(2, 4)):
                extra = generate_fraud_transaction(user_dict, fraud_date, "rapid_fire")
                extra["timestamp"] = txn["timestamp"] + timedelta(minutes=random.randint(1, 5))
                all_transactions.append(extra)

print(f"Generated {len(all_transactions):,} total transactions for {NUM_USERS} users.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 8. Label and Combine All Transactions into a DataFrame
# 
# Assemble the final DataFrame sorted by timestamp with proper data types.

# CELL ********************

txn_df = pd.DataFrame(all_transactions)

# Sort by timestamp and reset index
txn_df = txn_df.sort_values("timestamp").reset_index(drop=True)

# Ensure proper data types
txn_df["timestamp"] = pd.to_datetime(txn_df["timestamp"])
txn_df["is_fraud"] = txn_df["is_fraud"].astype(int)
txn_df["amount"] = txn_df["amount"].astype(float)

fraud_count = txn_df["is_fraud"].sum()
total_count = len(txn_df)
fraud_pct = fraud_count / total_count * 100

print(f"Total transactions: {total_count:,}")
print(f"Legitimate:         {total_count - fraud_count:,} ({100 - fraud_pct:.1f}%)")
print(f"Fraudulent:         {fraud_count:,} ({fraud_pct:.1f}%)")
print(f"\nColumns: {list(txn_df.columns)}")
print(f"\nDate range: {txn_df['timestamp'].min()} → {txn_df['timestamp'].max()}")
txn_df.head(10)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 9. Add Derived Features for Fraud Detection
# 
# Engineer features that are highly predictive for fraud models:
# - **distance_from_home** — Haversine distance between merchant and user's home
# - **hour_of_day / day_of_week** — Temporal features
# - **time_since_last_txn** — Seconds since the user's previous transaction
# - **rolling_avg_amount** — User's rolling 7-day average transaction amount
# - **txn_count_last_1h / txn_count_last_24h** — Velocity features
# - **amount_deviation** — How far this amount deviates from the user's mean

# CELL ********************

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in km between two lat/lon points using the Haversine formula."""
    R = 6371  # Earth's radius in km
    lat1, lon1, lat2, lon2 = map(np.radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = np.sin(dlat / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon / 2) ** 2
    return 2 * R * np.arcsin(np.sqrt(a))

# Merge user home location into transactions
txn_df = txn_df.merge(
    users_df[["user_id", "home_lat", "home_lon"]],
    on="user_id",
    how="left",
    suffixes=("", "_home"),
)

# Distance from home (km)
txn_df["distance_from_home_km"] = haversine_distance(
    txn_df["home_lat"], txn_df["home_lon"],
    txn_df["merchant_lat"], txn_df["merchant_lon"],
)
txn_df["distance_from_home_km"] = txn_df["distance_from_home_km"].round(2)

# Temporal features
txn_df["hour_of_day"] = txn_df["timestamp"].dt.hour
txn_df["day_of_week"] = txn_df["timestamp"].dt.dayofweek  # 0=Mon, 6=Sun

# Time since last transaction per user (in seconds)
txn_df = txn_df.sort_values(["user_id", "timestamp"])
txn_df["time_since_last_txn_sec"] = (
    txn_df.groupby("user_id")["timestamp"].diff().dt.total_seconds()
)
txn_df["time_since_last_txn_sec"] = txn_df["time_since_last_txn_sec"].fillna(0)

# Rolling average amount per user (last 10 transactions)
txn_df["rolling_avg_amount"] = (
    txn_df.groupby("user_id")["amount"]
    .transform(lambda x: x.rolling(10, min_periods=1).mean())
    .round(2)
)

# Amount deviation from user's overall mean
user_means = txn_df.groupby("user_id")["amount"].transform("mean")
user_stds = txn_df.groupby("user_id")["amount"].transform("std").fillna(1)
txn_df["amount_zscore"] = ((txn_df["amount"] - user_means) / user_stds).round(3)

# Transaction count in last 1 hour and 24 hours per user
txn_df = txn_df.sort_values(["user_id", "timestamp"]).reset_index(drop=True)

def count_recent_txns(group, window_hours):
    """Count transactions within a rolling time window for a user."""
    timestamps = group["timestamp"].values
    counts = []
    for i, ts in enumerate(timestamps):
        window_start = ts - np.timedelta64(window_hours, "h")
        count = np.sum((timestamps[:i] >= window_start) & (timestamps[:i] < ts))
        counts.append(count)
    return pd.Series(counts, index=group.index)

txn_df["txn_count_last_1h"] = txn_df.groupby("user_id", group_keys=False).apply(
    lambda g: count_recent_txns(g, 1)
).astype(int)

txn_df["txn_count_last_24h"] = txn_df.groupby("user_id", group_keys=False).apply(
    lambda g: count_recent_txns(g, 24)
).astype(int)

# Drop helper columns
txn_df = txn_df.drop(columns=["home_lat", "home_lon"])

print(f"Added {6} derived features. Final shape: {txn_df.shape}")
print(f"\nAll columns: {list(txn_df.columns)}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 10. Explore Transaction Data Distribution
# 
# Visualize fraud vs. legitimate transaction patterns by amount, category, time, and distance from home.

# CELL ********************

import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams["figure.figsize"] = (14, 4)
matplotlib.rcParams["figure.dpi"] = 100

fig, axes = plt.subplots(1, 4, figsize=(20, 4))

# 1. Amount distribution by fraud label
for label, color, name in [(0, "#2ecc71", "Legitimate"), (1, "#e74c3c", "Fraud")]:
    subset = txn_df[txn_df["is_fraud"] == label]["amount"]
    axes[0].hist(subset.clip(upper=2000), bins=50, alpha=0.6, color=color, label=name)
axes[0].set_title("Transaction Amount Distribution")
axes[0].set_xlabel("Amount ($)")
axes[0].legend()

# 2. Fraud count by category
fraud_by_cat = txn_df[txn_df["is_fraud"] == 1].groupby("merchant_category").size().sort_values()
fraud_by_cat.plot.barh(ax=axes[1], color="#e74c3c", alpha=0.8)
axes[1].set_title("Fraud Count by Merchant Category")
axes[1].set_xlabel("Fraud Transactions")

# 3. Transactions by hour of day
for label, color, name in [(0, "#2ecc71", "Legitimate"), (1, "#e74c3c", "Fraud")]:
    subset = txn_df[txn_df["is_fraud"] == label]
    hourly = subset.groupby("hour_of_day").size()
    axes[2].plot(hourly.index, hourly.values, color=color, label=name, marker="o", markersize=3)
axes[2].set_title("Transactions by Hour of Day")
axes[2].set_xlabel("Hour")
axes[2].legend()

# 4. Distance from home
for label, color, name in [(0, "#2ecc71", "Legitimate"), (1, "#e74c3c", "Fraud")]:
    subset = txn_df[txn_df["is_fraud"] == label]["distance_from_home_km"]
    axes[3].hist(subset.clip(upper=5000), bins=50, alpha=0.6, color=color, label=name)
axes[3].set_title("Distance from Home (km)")
axes[3].set_xlabel("Distance (km)")
axes[3].legend()

plt.tight_layout()
plt.show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Summary statistics
print("=" * 60)
print("FRAUD TYPE BREAKDOWN")
print("=" * 60)
print(txn_df[txn_df["is_fraud"] == 1]["fraud_type"].value_counts().to_string())

print("\n" + "=" * 60)
print("AMOUNT STATISTICS BY FRAUD LABEL")
print("=" * 60)
print(txn_df.groupby("is_fraud")["amount"].describe().round(2).to_string())

print("\n" + "=" * 60)
print("DISTANCE FROM HOME (KM) BY FRAUD LABEL")
print("=" * 60)
print(txn_df.groupby("is_fraud")["distance_from_home_km"].describe().round(2).to_string())

print("\n" + "=" * 60)
print("SAMPLE FRAUDULENT TRANSACTIONS")
print("=" * 60)
txn_df[txn_df["is_fraud"] == 1].sample(10, random_state=42)[
    ["user_id", "timestamp", "amount", "merchant_name", "merchant_category",
     "merchant_city", "fraud_type", "distance_from_home_km"]
]

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 11. Ingest Customers Table into Eventhouse KQL Database
# 
# Create the **Customers** reference table in the Eventhouse (KQL database) so that streaming transactions can be joined with customer identity and location data.
# 
# ### Prerequisites
# - An **Eventhouse** already exists in your Fabric workspace with a KQL database
# - Replace `EVENTHOUSE_URI` and `KQL_DATABASE` below with your values
# 
# The table schema maps each `user_id` to its Entra ID identity (`user_principal_name`) and full address, enabling real-time enrichment of transactions with customer context.

# CELL ********************

# ── Eventhouse KQL Database Configuration ─────────────────
EVENTHOUSE_URI = "https://trd-7zrfeffcyzsvvtxbn2.z8.kusto.fabric.microsoft.com"  # Replace with your Eventhouse Query URI
KQL_DATABASE = "MyFraud_EH"                                     # Replace with your KQL database name

# ── Build Customers table columns for KQL ─────────────────
customers_cols = [
    "user_id", "first_name", "last_name", "display_name",
    "user_principal_name", "email", "age", "gender",
    "street_address", "home_city", "home_state", "postal_code",
    "country_code", "country", "home_lat", "home_lon",
    "credit_limit", "account_created",
]
customers_df = users_df[customers_cols].copy()
customers_df["account_created"] = pd.to_datetime(customers_df["account_created"]).dt.strftime("%Y-%m-%dT%H:%M:%SZ")

print(f"Customers table: {len(customers_df)} rows, {len(customers_df.columns)} columns")
print(f"Columns: {list(customers_df.columns)}")
customers_df

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import io
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.kusto.data.helpers import dataframe_from_result_table

# ── Connect to Eventhouse using Fabric managed identity ───
access_token = notebookutils.credentials.getToken(EVENTHOUSE_URI)
kcsb = KustoConnectionStringBuilder.with_aad_application_token_authentication(
    EVENTHOUSE_URI, access_token
)
kusto_client = KustoClient(kcsb)

# ── Create the Customers table if it doesn't exist ────────
create_table_cmd = """
.create-merge table Customers (
    user_id: string,
    first_name: string,
    last_name: string,
    display_name: string,
    user_principal_name: string,
    email: string,
    age: int,
    gender: string,
    street_address: string,
    home_city: string,
    home_state: string,
    postal_code: string,
    country_code: string,
    country: string,
    home_lat: real,
    home_lon: real,
    credit_limit: real,
    account_created: datetime
)
"""
kusto_client.execute_mgmt(KQL_DATABASE, create_table_cmd)
print("✅ Customers table created/verified in Eventhouse.")

# ── Ingest customer data via inline ingestion ─────────────
# Escape values that may contain commas or special characters
def escape_csv_value(v):
    """Escape a value for KQL inline CSV ingestion."""
    s = "" if pd.isna(v) else str(v)
    if "," in s or '"' in s or "\n" in s:
        return '"' + s.replace('"', '""') + '"'
    return s

rows = []
for _, row in customers_df.iterrows():
    values = [escape_csv_value(row[col]) for col in customers_cols]
    rows.append(",".join(values))

inline_data = "\n".join(rows)

ingest_cmd = f""".ingest inline into table Customers <|
{inline_data}
"""

kusto_client.execute_mgmt(KQL_DATABASE, ingest_cmd)
print(f"✅ Ingested {len(customers_df)} customer records into Eventhouse Customers table.")

# ── Verify ingestion ──────────────────────────────────────
result = kusto_client.execute(KQL_DATABASE, "Customers | count")
count_table = dataframe_from_result_table(result.primary_results[0])
print(f"   Customers table now has {count_table.iloc[0, 0]} rows.")
print(f"\n💡 You can now join transactions with customers in KQL:")
print(f"   Transactions | join kind=inner Customers on user_id")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# ## 12. Stream Transactions to Fabric Eventstream (Real-Time Intelligence)
# 
# Send all generated transactions as a **live 30-minute stream** to a Fabric **Eventstream** via its Event Hub–compatible Custom App endpoint. This simulates real-time card activity for dashboards, KQL queries, and alerting.
# 
# ### How to set up the Eventstream
# 
# 1. **Create an Eventstream** — In your Fabric workspace, click **+ New item → Eventstream**. Give it a name (e.g., `es-credit-card-transactions`).
# 2. **Add a Custom App source** — In the Eventstream canvas, click **New source → Custom App**. Name it (e.g., `credit-card-generator`). Click **Add**.
# 3. **Store the connection string in Azure Key Vault** — Once the Custom App source is created, click on it and select the **Keys** tab. Copy the **Connection string–primary key** and store it as a secret in your Azure Key Vault (e.g., secret name `EventHubConnectionString`).
# 4. **Update the Key Vault URL and secret name below** — Replace `KEY_VAULT_URL` and `SECRET_NAME` in the next cell with your Key Vault URI and secret name.
# 5. **Add a destination** — In the Eventstream canvas, add a destination:
#    - **KQL Database** → to route events into an Eventhouse table for KQL queries
#    - **Lakehouse** → to persist events as Delta tables
#    - **Reflex** → to trigger real-time alerts on fraud patterns
# 6. **Run the cells below** — The generator will compress 6 months of transactions into 30 minutes of real-time streaming, sending events at their proportional pace with progress updates.
# 
# > **Note:** The Event Hub name (`EntityPath`) is already embedded in the connection string — you do **not** need to set it separately.
# 
# > **Security:** The connection string is retrieved at runtime from Azure Key Vault using `notebookutils.credentials.getSecret`, so no secrets are stored in the notebook.


# CELL ********************

import json
import time
from datetime import datetime, timedelta, timezone
from azure.eventhub import EventHubProducerClient, EventData

# ── Azure Key Vault Configuration ─────────────────────────
# Replace with your Key Vault URL and the secret name storing the connection string
KEY_VAULT_URL = "https://demokvnso.vault.azure.net/"
SECRET_NAME = "EventHubConnectionString"

# Retrieve the Event Hub connection string from Azure Key Vault
EVENT_HUB_CONNECTION_STRING = notebookutils.credentials.getSecret(KEY_VAULT_URL, SECRET_NAME)

# ── Streaming Parameters ──────────────────────────────────
STREAM_DURATION_MINUTES = 30   # Total wall-clock streaming window
BATCH_SIZE = 50                # Events per Event Hub batch send

# ── Prepare the stream ────────────────────────────────────
# Remap 6 months of transactions into a 30-minute real-time window.
# Each transaction gets a new "stream_timestamp" proportional to its
# position in the original date range, so the demo plays back at ~333x speed.

stream_start = datetime.now(timezone.utc)
stream_end = stream_start + timedelta(minutes=STREAM_DURATION_MINUTES)

orig_min = txn_df["timestamp"].min()
orig_max = txn_df["timestamp"].max()
orig_span = (orig_max - orig_min).total_seconds()
stream_span = STREAM_DURATION_MINUTES * 60  # seconds

# Sort by original timestamp and compute stream offsets
stream_df = txn_df.sort_values("timestamp").reset_index(drop=True).copy()
stream_df["_orig_offset"] = (stream_df["timestamp"] - orig_min).dt.total_seconds()
stream_df["_stream_offset"] = stream_df["_orig_offset"] / orig_span * stream_span
stream_df["stream_timestamp"] = stream_df["_stream_offset"].apply(
    lambda s: (stream_start + timedelta(seconds=s)).isoformat()
)

# Columns to send (exclude internal helper cols)
send_cols = [
    "transaction_id", "user_id", "stream_timestamp", "amount",
    "merchant_name", "merchant_category", "merchant_city", "merchant_state",
    "merchant_lat", "merchant_lon", "is_fraud", "fraud_type",
    "distance_from_home_km", "hour_of_day", "day_of_week",
    "time_since_last_txn_sec", "rolling_avg_amount", "amount_zscore",
    "txn_count_last_1h", "txn_count_last_24h",
]
send_cols = [c for c in send_cols if c in stream_df.columns]

print(f"🚀 Streaming {len(stream_df):,} transactions over {STREAM_DURATION_MINUTES} minutes")
print(f"   Start: {stream_start.strftime('%H:%M:%S UTC')}  →  End: {stream_end.strftime('%H:%M:%S UTC')}")
print(f"   Compression: {orig_span/stream_span:.0f}x  ({(orig_max - orig_min).days} days → {STREAM_DURATION_MINUTES} min)")
print(f"   Batch size: {BATCH_SIZE} events")
print()

# ── Stream events ─────────────────────────────────────────
producer = EventHubProducerClient.from_connection_string(EVENT_HUB_CONNECTION_STRING)

sent_count = 0
fraud_sent = 0
batch_count = 0
errors = 0
t0 = time.time()

try:
    i = 0
    while i < len(stream_df):
        # Wait until it's time to send this event
        target_offset = stream_df.iloc[i]["_stream_offset"]
        elapsed = time.time() - t0
        if target_offset > elapsed:
            time.sleep(target_offset - elapsed)

        # Collect all events that should have been sent by now
        elapsed = time.time() - t0
        batch_rows = []
        while i < len(stream_df) and stream_df.iloc[i]["_stream_offset"] <= elapsed:
            batch_rows.append(i)
            i += 1

        # Send in batches of BATCH_SIZE
        for start in range(0, len(batch_rows), BATCH_SIZE):
            chunk_idxs = batch_rows[start : start + BATCH_SIZE]
            try:
                event_batch = producer.create_batch()
                for idx in chunk_idxs:
                    row = stream_df.iloc[idx]
                    event_json = json.dumps(
                        {col: (row[col] if not isinstance(row[col], (float, np.floating)) or not np.isnan(row[col])
                               else None)
                         for col in send_cols},
                        default=str,
                    )
                    event_batch.add(EventData(event_json))
                producer.send_batch(event_batch)
                batch_count += 1
                sent_count += len(chunk_idxs)
                fraud_sent += sum(1 for idx in chunk_idxs if stream_df.iloc[idx]["is_fraud"] == 1)
            except Exception as e:
                errors += 1
                if errors <= 3:
                    print(f"⚠ Batch send error: {e}")

        # Progress update every ~60 seconds
        mins_elapsed = elapsed / 60
        if batch_count > 0 and batch_count % max(1, int(len(stream_df) / BATCH_SIZE / 30)) == 0:
            pct = sent_count / len(stream_df) * 100
            print(
                f"  [{mins_elapsed:5.1f} min] {sent_count:>6,} / {len(stream_df):,} sent "
                f"({pct:5.1f}%)  |  fraud: {fraud_sent}  |  batches: {batch_count}"
            )

finally:
    producer.close()

total_time = time.time() - t0
print()
print(f"✅ Streaming complete!")
print(f"   Total sent:    {sent_count:,} events in {batch_count:,} batches")
print(f"   Fraud events:  {fraud_sent:,} ({fraud_sent/max(sent_count,1)*100:.1f}%)")
print(f"   Wall clock:    {total_time/60:.1f} minutes")
print(f"   Errors:        {errors}")
print(f"\n💡 Check your Eventstream canvas — events should appear in the data preview within seconds.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
