-- =====================================================
-- PLAYER OVERVIEW
-- =====================================================

-- =====================================================
-- KPI SUMMARY 
-- =====================================================

SELECT 		
			COUNT(DISTINCT player_name)				AS distinct_players,
			ROUND(
				COUNT(DISTINCT id_game)::numeric /
				NULLIF(COUNT(DISTINCT player_name), 0), 
			2)										AS avg_matches_per_player,

			ROUND(
				(SELECT SUM(duration_seconds) 
				 FROM bi_magic.vw_game_level_base) /
				NULLIF(COUNT(DISTINCT player_name), 0) /
				3600,
			2)										AS avg_hours_played

			
FROM bi_magic.fact_games;

-- =====================================================
-- TOP 3 PLAYER CHARTS
-- =====================================================

WITH top_3_matches AS(

	SELECT		player_name,
				'matches' 											AS metric,
				COUNT(DISTINCT id_game)								AS metric_value,
				RANK() OVER(ORDER BY COUNT(DISTINCT id_game) DESC)	AS ranking
	
	FROM		bi_magic.fact_games
	GROUP BY	player_name
),

top_3_victories AS(

	SELECT		player_name,
				'victories'								AS metric,
				COUNT(*) FILTER(WHERE winner IS TRUE) 	AS metric_value,
				RANK() OVER(ORDER BY COUNT(*) FILTER(WHERE winner IS TRUE) DESC) AS ranking

	FROM		bi_magic.fact_games
	GROUP BY	player_name
),

top_3_win_rate AS(

	SELECT		a.player_name,
				'win_rate'								AS metric,
				ROUND(
				b.metric_value::numeric /
				NULLIF(a.metric_value, 0), 2)			AS metric_value,
				RANK() OVER(ORDER BY 
								(b.metric_value::numeric / 
								NULLIF(a.metric_value, 0))
							DESC) 						AS ranking

	FROM		top_3_matches a
	LEFT JOIN	top_3_victories b ON a.player_name = b.player_name
	WHERE		a.metric_value >= 5
	GROUP BY	a.player_name,
				a.metric_value,
				b.metric_value
)

SELECT 	player_name, metric, metric_value, ranking	FROM top_3_matches		WHERE ranking <= 3
UNION ALL
SELECT 	player_name, metric, metric_value, ranking	FROM top_3_victories	WHERE ranking <= 3
UNION ALL
SELECT 	player_name, metric, metric_value, ranking	FROM top_3_win_rate		WHERE ranking <= 3
ORDER BY metric, ranking;


-- =====================================================
-- DEEP-DIVE
-- =====================================================

-- =====================================================
-- DEEP-DIVE - KPI SUMMARY
-- =====================================================

WITH score AS(

	SELECT 		a.player_name,
				COUNT(DISTINCT a.id_game) 												AS M,  -- Match Points
				COUNT(*) FILTER(WHERE a.winner IS TRUE AND a.num_of_players = 3) * 4	AS V3, -- Victory 3p Points
				COUNT(*) FILTER(WHERE a.winner IS TRUE AND a.num_of_players >= 4) * 5	AS V4, -- Victory 4p Points
				COUNT(*) FILTER(WHERE a.combo IS TRUE) * - 3							AS C,  -- Combo Penalty
				COALESCE(b.bonus_points, 0)												AS B   -- Bonus Points

	FROM 		bi_magic.fact_games a
	LEFT JOIN 	bi_magic.ranking_points b ON a.player_name = b.player AND b.season IS NULL
	GROUP BY	a.player_name,
				b.bonus_points
)

-- =====================================================
-- DEEP-DIVE - SCORE BREAKIN DOWN
-- =====================================================

/*
SELECT 		*,
			M + V3 + V4 + C		AS base_score,
			M + V3 + V4 + C + B AS total_score,
			RANK() OVER(ORDER BY (M + V3 + V4 + C + B) DESC)
FROM 		score
ORDER BY	player_name
*/

SELECT 		a.player_name,
			COUNT(DISTINCT a.id_game) 											AS matches,
			COUNT(*) FILTER(WHERE a.winner IS TRUE)								AS total_victories,
			ROUND(COUNT(*) FILTER(WHERE a.winner IS TRUE)::numeric /
			NULLIF(COUNT(DISTINCT a.id_game), 0), 2)							AS win_rate,			
			AVG(a.duration)														AS avg_match_duration,
			SUM(a.duration)														AS time_played,
			b.M + b.V3 + b.V4 + b.C + b.B										AS total_score,


			COUNT(DISTINCT a.commander)											AS decks,	
			COUNT(DISTINCT a.id_game) FILTER(WHERE a.num_of_players = 3)		AS matches_3p,
			COUNT(DISTINCT a.id_game) FILTER(WHERE a.num_of_players = 4)		AS matches_4p,
			COUNT(*) FILTER(WHERE a.winner IS TRUE AND a.num_of_players = 3)	AS victories_3p,
			COUNT(*) FILTER(WHERE a.winner IS TRUE AND a.num_of_players = 4)	AS victories_4p,
			COUNT(*) FILTER(WHERE a.winner IS FALSE)							AS defeats,
			COUNT(*) FILTER(WHERE a.combo IS TRUE)								AS combos,
			AVG(a.duration) FILTER(WHERE a.winner IS TRUE)						AS avg_winner_duration,
			b.M + b.V3 + b.V4 + b.C 											AS base_score,
			
			ROUND((b.M + b.V3 + b.V4 + b.C + b.B) /
			SUM(EXTRACT(EPOCH FROM a.duration)) * 3600, 1)						AS score_per_hour_played

FROM 		bi_magic.fact_games a
LEFT JOIN	score b ON a.player_name = b.player_name
GROUP BY	a.player_name,
			b.M,
			b.V3,
			b.V4,
			b.C,
			b.B;



-- =====================================================
-- DEEP-DIVE - HIGHLIGHTS
-- =====================================================

-- Opponents Defeated
WITH participated_games AS(

	SELECT 		id_game,
				player_name
			
	FROM 		bi_magic.fact_games
),

win_games AS(

	SELECT 		id_game,
				player_name
				
	FROM 		bi_magic.fact_games
	WHERE		winner IS TRUE
),

opponents_faced AS(

	SELECT 		b.id_game,
				b.player_name,
				a.player_name	AS opponent
				
	FROM 		bi_magic.fact_games a
	INNER JOIN	participated_games b ON a.id_game = b.id_game AND a.player_name <> b.player_name
),

opponents_defeated AS(

	SELECT 		b.id_game,
				b.player_name 	AS winner,
				a.player_name	AS opponent
				
	FROM 		bi_magic.fact_games a
	INNER JOIN	win_games b ON a.id_game = b.id_game AND a.player_name <> b.player_name
),

games_against AS(

	SELECT		a.player_name,
				COUNT(DISTINCT a.opponent) AS opponents_faced,
				COUNT(DISTINCT b.opponent) AS opponents_defeated
	
	FROM 		opponents_faced a
	LEFT JOIN 	opponents_defeated b ON a.player_name = b.winner
	GROUP BY	a.player_name
)


SELECT 		a.player_name,
			MAX(a.date)															AS last_game,
			MAX(a.date) FILTER(WHERE a.winner IS TRUE)							AS last_victory,
			CURRENT_DATE - (MAX(a.date) FILTER(WHERE a.winner IS TRUE))			AS days_since_last_victory,
			CURRENT_DATE - MAX(a.date)											AS days_since_last_game,
			MIN(a.duration) FILTER(WHERE a.winner IS TRUE)						AS fastest_game_win,
			MIN(a.duration) FILTER(WHERE a.winner IS FALSE)						AS fastest_game_defeat,
			MAX(a.duration)														AS longest_game,
			MAX(b.opponents_faced)												AS opponents_faced,
			MAX(b.opponents_defeated)											AS opponents_defeated,
			c.current_streak_type,
			MAX(c.current_streak_value)											AS current_streak_value,
			MAX(c.max_win_streak)												AS longest_win_streak,
			RANK() OVER(ORDER BY COUNT(DISTINCT a.id_game) DESC)				AS matches_ranking,
			RANK() OVER(ORDER BY COUNT(*) FILTER(WHERE a.winner IS TRUE) DESC)	AS victories_ranking,
			RANK() OVER(ORDER BY (
							COUNT(*) FILTER(WHERE a.winner IS TRUE)::numeric /
							NULLIF(COUNT(DISTINCT a.id_game), 0)
								  ) DESC)										AS win_rate_ranking

FROM 		bi_magic.fact_games a
LEFT JOIN	games_against b ON a.player_name = b.player_name
LEFT JOIN	bi_magic.players_streak c ON a.player_name = c.player_name
GROUP BY	a.player_name,
			c.current_streak_type;



-- =====================================================
-- DEEP-DIVE - GAMES OVER TIME
-- =====================================================

SELECT		player_name,
			CONCAT(
				EXTRACT(YEAR FROM date), '-',
				EXTRACT(MONTH FROM date)
			)										AS year_month,
			COUNT(DISTINCT id_game)					AS matches,
			COUNT(*) FILTER(WHERE winner IS TRUE)	AS victories

FROM 		bi_magic.fact_games
GROUP BY	1, 2;



-- =====================================================
-- DEEP-DIVE - COMMANDER BREAKDOWN
-- =====================================================

SELECT 		player_name,
			commander,
			COUNT(DISTINCT id_game) 				AS matches,
			COUNT(*) FILTER(WHERE winner IS TRUE)	AS victories,
			COUNT(*) FILTER(WHERE winner IS FALSE)	AS defeats,
			ROUND(
			COUNT(*) FILTER(WHERE winner IS TRUE)::numeric /
			NULLIF(COUNT(DISTINCT id_game), 0), 
			2)										AS win_rate,
			COUNT(*) FILTER(WHERE combo IS TRUE)	AS combo

FROM 		bi_magic.fact_games
GROUP BY	player_name,
			commander;



-- =====================================================
-- DEEP-DIVE - LAST 6 GAMES | X VICTORIES
-- =====================================================

WITH last_games AS(

	SELECT		player_name,
				id_game,
				date,
				commander,
				num_of_players,
				duration,
				winner,
				ROW_NUMBER() OVER (PARTITION BY player_name ORDER BY id_game DESC) AS game_order
	
	FROM 		bi_magic.fact_games
	ORDER BY	player_name,
				id_game
)


SELECT			player_name,
				id_game,
				date,
				commander,
				num_of_players,
				duration,
				winner

FROM 			last_games
WHERE			game_order <= 6
ORDER BY		player_name,
				game_order;



-- =====================================================
-- DEEP-DIVE - PLAYER METRICS BY STARTING POSITION
-- =====================================================

SELECT		player_name,
			CASE
				WHEN position = 5 THEN 4
				ELSE position
			END 										AS starting_position,
			COUNT(DISTINCT id_game) 					AS matches,
			COUNT(*) FILTER(WHERE winner IS TRUE)		AS victories,
			COUNT(*) FILTER(WHERE winner IS FALSE)		AS defeats,
			ROUND(
			COUNT(*) FILTER(WHERE winner IS TRUE)::numeric /
			NULLIF(COUNT(DISTINCT id_game), 0), 2)			AS win_rate
			

FROM 		bi_magic.fact_games
GROUP BY	1, 2
ORDER BY	1, 2;

