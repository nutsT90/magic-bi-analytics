# 🎯 Magic: The Gathering BI Analytics Project

![Python](https://img.shields.io/badge/Python-3.12-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-blue)
![Power BI](https://img.shields.io/badge/PowerBI-Visualization-yellow)
![Status](https://img.shields.io/badge/Status-Active-success)

## Project Overview

This project is an end-to-end Business Intelligence solution built to analyze Magic: The Gathering Commander games.

It simulates a real-world analytics workflow, covering the full pipeline:
- Data extraction from external sources
- Data transformation and validation
- Data modeling in a relational database
- Interactive dashboard creation

The goal is to demonstrate strong fundamentals in data engineering, data modeling, and business intelligence.

## Architecture

Google Sheets → Python ETL → PostgreSQL → Power BI

## Tech Stack

- **Python** — Data extraction, transformation, and loading (ETL)
- **PostgreSQL** — Data storage and modeling (star schema)
- **Power BI** — Data visualization and dashboarding
- **Google Sheets** — Data source

## Data Model

The project follows a **star schema design**.

### Fact Table
- `FACT_GAMES` → 1 row per player per game

### Dimension Tables
- `DIM_PLAYER`
- `DIM_COMMANDER`
- `DIM_COLOR`
- `DIM_SEASON`
- `DIM_SCORE_RULE`

## ETL Process

### Extract
- Data is extracted from Google Sheets using Python

### Transform
- Data cleaning and validation
- Type conversion (dates, booleans, durations)
- Business rules applied
- Error handling and logging

### Load
- Full refresh strategy:
  - `TRUNCATE` + `INSERT`
- Data loaded into PostgreSQL

## Key Features

- Dynamic performance metrics:
  - Matches
  - Victories (3-player and 4-player)
  - Win rate
  - Score calculation
  - Combos tracking

- Data validation:
  - Invalid rows detection and logging
  - Format validation (duration, color, etc.)

- Modular architecture:
  - `extract`, `transform`, `load` separation
  - Reusable components

## SQL Layer

In addition to the Python ETL pipeline, this project includes SQL scripts responsible for analytical logic inside PostgreSQL.

This layer is used to:
- reproduce ranking rules directly in the database
- apply business logic for leaderboard eligibility
- generate final analytical tables consumed by Power BI

Example:
- `sql/ranking_points.sql` → creates the `ranking_points` table with bonus score logic by player and season

## Dashboard

### Season Overview
![Season Overview](assets/screenshots/season_overview_single.png)

### All Seasons Overview
![All Seasons Overview](assets/screenshots/season_overview_all.png)

*More screenshots will be added here.*

Example structure:

- Main dashboard
- Player performance analysis
- Commander analysis
- Score breakdown

## Additional Analytics (Python Layer)

The project also includes a Python-based analytics layer to:

- Reproduce BI metrics outside Power BI
- Validate calculations between layers
- Perform advanced analysis not easily handled in dashboards

Example use case:
- Player vs opponent performance analysis

## How to Run

1. Clone the repository:

    git clone https://github.com/nutsT90/magic-bi-analytics.git

2. Navigate to the project folder:

    cd magic-bi-analytics

3. Create a `.env` file based on `.env.example`

4. Install dependencies:

    pip install -r requirements.txt

5. Run the pipeline:

    python src/main.py

## Future Improvements

- SQL validation layer for metric verification
- Dashboard enhancements and storytelling improvements
- PySpark implementation for scalability
- Cloud pipeline simulation (scheduled execution)
- Data quality monitoring
- Python-based dashboard and metrics replication

## Project Status

This project is actively maintained and continuously improved to simulate real-world data workflows.

## Author

Thiago Mattos Santos
