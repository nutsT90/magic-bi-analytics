-- =====================================================
-- ALL SEASONS OVERVIEW
-- =====================================================

-- =====================================================
-- KPI SUMMARY - SCORE PREPARATION
-- =====================================================

DROP TABLE IF EXISTS 	temp_score_summary;
CREATE TEMP TABLE 		temp_score_summary AS

WITH all_player_seasons AS(

	SELECT 		player_name 	AS player,
				'all' 			AS season
	
	FROM 		bi_magic.dim_player
	
	UNION ALL 	
	
	SELECT 		a.player_name			AS player,
				CAST(b.season AS TEXT) 	AS season
	
	FROM 		bi_magic.dim_player a
	CROSS JOIN	bi_magic.dim_season b

),


base_score AS (

	SELECT 		player_name 			AS player,
				CAST(
					EXTRACT(YEAR FROM date) AS TEXT
				) 						AS season,
				COUNT(*) 				AS M,
				SUM(
					CASE
						WHEN num_of_players = 3 AND winner IS TRUE THEN 4
						ELSE 0
					END
				) 						AS V3,
				SUM(
					CASE
						WHEN num_of_players >= 4 AND winner IS TRUE THEN 5
						ELSE 0
					END
				)						AS V4,
				SUM(
					CASE
						WHEN combo IS TRUE THEN -3
						ELSE 0
					END
				)						AS C
	
	FROM 		bi_magic.fact_games
	GROUP BY 	1, 2
),

-- NULL season in ranking_points represents all seasons
score_summary AS (

	SELECT		a.player,
				a.season,
				COALESCE(b.bonus_points, 0) 	AS bonus_points,
				COALESCE(
					CASE
						WHEN a.season = 'all' THEN d.base_score 
						ELSE c.M +		-- Match Points
							 c.V3 +		-- Victory 3p Points
							 c.V4 +		-- Victory 4p Points
							 c.C		-- Combo Penalty
					END, 0)						AS base_score,
				c.M 							AS match_point
				
	FROM 		all_player_seasons a
	LEFT JOIN 	bi_magic.ranking_points b ON a.player = b.player AND a.season = COALESCE(b.season, 'all')
	LEFT JOIN 	base_score c ON a.player = c.player AND a.season = c.season
	LEFT JOIN 	
	(
		SELECT 	player,
				'all' AS season,
				SUM(M +	V3 + V4 + C) 	AS base_score
		FROM 	base_score
		GROUP BY player
	) d 		ON a.player = d.player AND a.season = d.season

)

SELECT 	* 
FROM 	score_summary;



-- =====================================================
-- KPI SUMMARY - SCORE
-- =====================================================

SELECT		SUM(base_score + bonus_points)	AS total_score,
			SUM(base_score)					AS base_score

FROM		temp_score_summary
WHERE		season = 'all';



-- =====================================================
-- KPI SUMMARY - MATCHES
-- =====================================================

SELECT 		COUNT(*) 									AS total_matches,
			AVG(duration_seconds) * INTERVAL '1 second'	AS avg_match_duration
FROM 		bi_magic.vw_game_level_base;



-- =====================================================
-- KPI SUMMARY - ENTITY COUNTS
-- =====================================================

SELECT 		COUNT(DISTINCT player_name) AS distinct_players,
			COUNT(DISTINCT commander)	AS distinct_commanders,
			COUNT(DISTINCT color)		AS distinct_colors
FROM 		bi_magic.fact_games;



-- =====================================================
-- TOP PLAYER BY SCORE
-- =====================================================

SELECT 		a.season,
			a.player,
			a.bonus_points 	+ 
			a.base_score 							AS total_score,
			a.bonus_points 	+ 
			a.base_score	-
			COALESCE(a.match_point, b.match_point) 	AS score_without_match_point,
			a.bonus_points,
			a.base_score,
			COALESCE(a.match_point, b.match_point) 	AS match_point
			
FROM 		temp_score_summary a
LEFT JOIN	
		(
			SELECT 		player,
						SUM(match_point) AS match_point
			FROM 		temp_score_summary
			WHERE 		season <> 'all'
			GROUP BY 	player
		) b ON a.player = b.player
ORDER BY	1 DESC, 3 DESC;



-- =====================================================
-- WIN RATE BY STARTING POSITION
-- =====================================================

-- Position 5 is grouped visually as starting position 4.
-- However, position 5 is removed from the denominator to avoid double-counting
-- games where both position 4 and position 5 exist in the same 4-player setup.

WITH win_rate_position AS (

	SELECT 		num_of_players,
				CASE 
					WHEN position > 4 THEN 4 
					ELSE position
				END AS starting_position,
	
				SUM(
					CASE
						WHEN winner IS TRUE THEN 1
						ELSE 0
					END
				) 					AS victories,
				COUNT(*) 			AS matches_position,
				SUM(
					CASE 
						WHEN position = 5 THEN 1 
						ELSE 0 
					END) 			AS position_5_matches
		
	FROM		bi_magic.fact_games
	GROUP BY	1, 2
)

SELECT 		num_of_players,
			starting_position,
			ROUND(
			    victories::numeric /
			    NULLIF(
			        CASE
			            WHEN num_of_players = 4 AND starting_position = 4
			                THEN matches_position - position_5_matches
			            ELSE matches_position
			        END,
			        0
			    )::numeric,
			    2
			) AS win_rate
					
FROM 		win_rate_position;
 		


-- =====================================================
-- METRIC EXPLORER
-- =====================================================

-- =====================================================
-- METRIC EXPLORER - PLAYER LAYER
-- =====================================================

-- Used by:
-- Matches vs Win Rate scatter plot
-- Player ranking metrics

SELECT 		player_name 							AS player,
			COUNT(*) 								AS matches,
			COUNT(*) FILTER (WHERE winner IS FALSE)	AS defeats,
			COUNT(*) FILTER (WHERE winner IS TRUE)	AS victories,

			COUNT(*) FILTER (WHERE winner IS TRUE) :: numeric / 
			NULLIF(COUNT(*), 0) 					AS win_rate
			

FROM 		bi_magic.fact_games
GROUP BY	player_name
ORDER BY	2 DESC, 4 DESC;

-- =====================================================
-- METRIC EXPLORER - COMMANDER LAYER
-- =====================================================

SELECT 		commander								AS commander,
			COUNT(*) 								AS matches,
			COUNT(*) FILTER (WHERE winner IS FALSE)	AS defeats,
			COUNT(*) FILTER (WHERE winner IS TRUE)	AS victories,
			COUNT(*) FILTER (WHERE winner IS TRUE) :: numeric / 
			NULLIF(COUNT(*), 0) 					AS win_rate
			

FROM 		bi_magic.fact_games
GROUP BY	commander
ORDER BY	2 DESC, 4 DESC;

-- =====================================================
-- METRIC EXPLORER - COLOR LAYER
-- =====================================================

SELECT 		color									AS color,
			COUNT(*) 								AS matches,			
			COUNT(*) FILTER (WHERE winner IS FALSE)	AS defeats,
			COUNT(*) FILTER (WHERE winner IS TRUE)	AS victories,
			COUNT(*) FILTER (WHERE winner IS TRUE) :: numeric / 
			NULLIF(COUNT(*), 0) 					AS win_rate
			

FROM 		bi_magic.fact_games
GROUP BY	color
ORDER BY	2 DESC, 4 DESC;



-- =====================================================
-- SEASON ACTIVITY AND AVG MATCH DURATION
-- =====================================================

SELECT 		CONCAT(
				EXTRACT(YEAR FROM game_date), '-',
				EXTRACT(MONTH FROM game_date)
			)									AS year_month,
			num_of_players,
			COUNT(DISTINCT id_game)				AS matches,
			AVG(duration_seconds) *	
			INTERVAL '1 second' 				AS avg_match_duration

FROM 		bi_magic.vw_game_level_base
GROUP BY	1, 2
ORDER BY 	1, 2;



DROP TABLE IF EXISTS temp_score_summary;
