# 🎯 Magic: The Gathering BI Analytics Project

## 📌 Overview
This project is an end-to-end Business Intelligence solution built to analyze Magic: The Gathering Commander games.

It simulates a real-world analytics workflow, including data extraction, transformation, storage, and visualization.

---

## 🧱 Architecture

Google Sheets → Python ETL → PostgreSQL → Power BI

---

## ⚙️ Tech Stack

- Python (ETL pipeline)
- PostgreSQL (Data warehouse)
- Power BI (Visualization)
- Google Sheets (Data source)

---

## 📊 Data Model

The project follows a **star schema** design:

### Fact Table
- FACT_GAMES → 1 row per player per game

### Dimensions
- DIM_PLAYER
- DIM_COMMANDER
- DIM_COLOR
- DIM_SEASON
- DIM_SCORE_RULE

---

## 🔄 ETL Process

### Extract
- Data extracted from Google Sheets

### Transform
- Data cleaning and validation
- Type conversions (date, boolean, interval)
- Business rules applied

### Load
- Full refresh strategy (TRUNCATE + INSERT)
- Data loaded into PostgreSQL

---

## 📈 Key Features

- Dynamic performance metrics (wins, win rate, score)
- Data validation and error handling
- Logging for ETL monitoring
- Clean and modular architecture

---

## 📊 Dashboard

*(Add screenshots here later)*

---

## ▶️ How to Run

1. Clone the repository
2. Create a `.env` file based on `.env.example`
3. Install dependencies
4. Run the pipeline:

```bash
python src/main.py