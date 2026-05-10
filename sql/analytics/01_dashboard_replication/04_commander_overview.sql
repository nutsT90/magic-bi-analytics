-- =====================================================
-- PLAYER OVERVIEW
-- =====================================================

-- =====================================================
-- KPI SUMMARY 
-- =====================================================

SELECT		COUNT(DISTINCT commander) 					AS distinct_commanders,
			ROUND(
			COUNT(DISTINCT id_game)::numeric /
			NULLIF(COUNT(DISTINCT commander), 0), 2) 	AS avg_matches

FROM		bi_magic.fact_games