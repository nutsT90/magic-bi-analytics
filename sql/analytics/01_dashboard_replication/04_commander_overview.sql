-- =====================================================
-- COMMANDER OVERVIEW
-- =====================================================

-- =====================================================
-- KPI SUMMARY 
-- =====================================================

SELECT		COUNT(DISTINCT commander) 					AS distinct_commanders,
			ROUND(
			COUNT(DISTINCT id_game)::numeric /
			NULLIF(COUNT(DISTINCT commander), 0), 2) 	AS avg_matches

FROM		bi_magic.fact_games;

-- =====================================================
-- TOP 3 COMMANDER CHARTS
-- =====================================================

WITH top_3_matches AS(

	SELECT		commander,
				'matches'											AS metric,
				COUNT(DISTINCT id_game) 							AS metric_value,
				RANK() OVER(ORDER BY COUNT(DISTINCT id_game) DESC)	AS ranking

	FROM		bi_magic.fact_games
	GROUP BY	commander
),

top_3_victories AS(

	SELECT		commander,
				'victories'															AS metric,
				COUNT(*) FILTER(WHERE winner IS TRUE)								AS metric_value,
				RANK() OVER(ORDER BY COUNT(*) FILTER(WHERE winner IS TRUE) DESC)	AS ranking

	FROM		bi_magic.fact_games
	GROUP BY	commander
),

top_3_win_rate AS(

	SELECT		a.commander,
				'win_rate' 									AS metric,
				ROUND(
				b.metric_value::numeric /
				NULLIF(a.metric_value, 0), 2)				AS metric_value,
				RANK() OVER(ORDER BY
								b.metric_value::numeric /
								NULLIF(a.metric_value, 0)
							DESC)	AS ranking

	FROM		top_3_matches a
	LEFT JOIN	top_3_victories b ON a.commander = b.commander
	WHERE		a.metric_value >= 5
	GROUP BY	a.commander,
				a.metric_value,
				b.metric_value

)

SELECT 	commander, metric, metric_value, ranking	FROM top_3_matches		WHERE ranking <= 3
UNION ALL
SELECT 	commander, metric, metric_value, ranking	FROM top_3_victories	WHERE ranking <= 3
UNION ALL
SELECT 	commander, metric, metric_value, ranking	FROM top_3_win_rate		WHERE ranking <= 3
ORDER BY metric, ranking;



-- =====================================================
-- DEEP-DIVE
-- =====================================================

-- =====================================================
-- DEEP-DIVE - KPI SUMMARY
-- =====================================================

WITH score AS(

	SELECT 		commander,
				COUNT(DISTINCT id_game) 											AS M,  -- Match Points
				COUNT(*) FILTER(WHERE winner IS TRUE AND num_of_players = 3) * 4	AS V3, -- Victory 3p Points
				COUNT(*) FILTER(WHERE winner IS TRUE AND num_of_players >= 4) * 5	AS V4, -- Victory 4p Points
				COUNT(*) FILTER(WHERE combo IS TRUE) * - 3							AS C   -- Combo Penalty

	FROM 		bi_magic.fact_games
	GROUP BY	commander
				
)

SELECT		a.commander,
			a.color,
			COUNT(DISTINCT a.id_game) 											AS matches,
			COUNT(*) FILTER(WHERE a.winner IS TRUE)								AS total_victories,
			ROUND(COUNT(*) FILTER(WHERE a.winner IS TRUE)::numeric /
			NULLIF(COUNT(DISTINCT a.id_game), 0), 2)							AS win_rate,
			AVG(a.duration)														AS avg_match_duration,
			SUM(a.duration)														AS time_played,

			
			COUNT(DISTINCT a.id_game) FILTER(WHERE a.num_of_players = 3)		AS matches_3p,
			COUNT(DISTINCT a.id_game) FILTER(WHERE a.num_of_players = 4)		AS matches_4p,
			COUNT(*) FILTER(WHERE a.winner IS TRUE AND a.num_of_players = 3)	AS victories_3p,
			COUNT(*) FILTER(WHERE a.winner IS TRUE AND a.num_of_players = 4)	AS victories_4p,
			COUNT(*) FILTER(WHERE a.winner IS FALSE)							AS defeats,
			COUNT(*) FILTER(WHERE a.combo IS TRUE)								AS combos,
			AVG(a.duration) FILTER(WHERE a.winner IS TRUE)						AS avg_winner_duration,
			MAX(b.M + b.V3 + b.V4 + b.C)										AS base_score,
			MAX(a.date)															AS last_game
			
FROM		bi_magic.fact_games a
LEFT JOIN	score b ON a.commander = b.commander
GROUP BY	a.commander,
			a.color;



-- =====================================================
-- DEEP-DIVE - HIGHLIGHTS
-- =====================================================

-- Opponents Defeated
WITH participated_games AS(

	SELECT 		id_game,
				commander,
				player_name
			
	FROM 		bi_magic.fact_games
),

win_games AS(

	SELECT 		id_game,
				commander,
				player_name
				
	FROM 		bi_magic.fact_games
	WHERE		winner IS TRUE
),

opponents_faced AS(

	SELECT 		b.id_game,
				b.commander,
				a.player_name	AS opponent
				
	FROM 		bi_magic.fact_games a
	INNER JOIN	participated_games b ON a.id_game = b.id_game AND a.player_name <> b.player_name
),

opponents_defeated AS(

	SELECT 		b.id_game,
				b.commander 	AS commander_winner,
				a.player_name	AS opponent
				
	FROM 		bi_magic.fact_games a
	INNER JOIN	win_games b ON a.id_game = b.id_game AND a.player_name <> b.player_name
),

games_against AS(

	SELECT		a.commander,
				COUNT(DISTINCT a.opponent) AS opponents_faced,
				COUNT(DISTINCT b.opponent) AS opponents_defeated
	
	FROM 		opponents_faced a
	LEFT JOIN 	opponents_defeated b ON a.commander = b.commander_winner
	GROUP BY	a.commander
),

commander_metrics AS (
    
	SELECT		commander,
		        COUNT(*) FILTER (WHERE winner IS TRUE)::numeric /
		        NULLIF(COUNT(DISTINCT id_game), 0) AS win_rate
    
	FROM 		bi_magic.fact_games		
    GROUP BY 	commander
	HAVING		COUNT(DISTINCT id_game) >= 5
)



SELECT 		a.commander,
			MAX(a.date) FILTER(WHERE a.winner IS TRUE)							AS last_victory,
			CURRENT_DATE - (MAX(a.date) FILTER(WHERE a.winner IS TRUE))			AS days_since_last_victory,
			CURRENT_DATE - MAX(a.date)											AS days_since_last_game,
			MIN(a.duration)														AS fastest_game,
			MAX(a.duration)														AS longest_game,
			COUNT(DISTINCT a.player_name)										AS commander_users,
			
			MAX(c.opponents_faced)												AS opponents_faced,
			MAX(c.opponents_defeated)											AS opponents_defeated,
			d.current_streak_type,
			MAX(d.current_streak_value)											AS current_streak_value,
			MAX(d.max_win_streak)												AS longest_win_streak,
			RANK() OVER(ORDER BY COUNT(DISTINCT a.id_game) DESC)				AS matches_ranking,
			RANK() OVER(ORDER BY COUNT(*) FILTER(WHERE a.winner IS TRUE) DESC)	AS victories_ranking,
            RANK() OVER (ORDER BY MAX(b.win_rate) DESC NULLS LAST)				AS win_rate_ranking

FROM 		bi_magic.fact_games a
LEFT JOIN	commander_metrics b ON a.commander = b.commander
LEFT JOIN	games_against c ON a.commander = c.commander
LEFT JOIN	bi_magic.commanders_streak d ON a.commander = d.commander
GROUP BY	a.commander,
			d.current_streak_type
ORDER BY	a.commander;



-- =====================================================
-- DEEP-DIVE - GAMES OVER TIME
-- =====================================================

SELECT		commander,
			CONCAT(
				EXTRACT(YEAR FROM date), '-',
				EXTRACT(MONTH FROM date)
			)										AS year_month,
			COUNT(DISTINCT id_game)					AS matches,
			COUNT(*) FILTER(WHERE winner IS TRUE)	AS victories

FROM 		bi_magic.fact_games
GROUP BY	1, 2;



-- =====================================================
-- DEEP-DIVE - LAST 10 GAMES | X VICTORIES
-- =====================================================

WITH last_games AS(

	SELECT		commander,
				id_game,
				date,
				num_of_players,
				duration,
				winner,
				ROW_NUMBER() OVER(PARTITION BY commander ORDER BY id_game DESC)	AS game_order
	
	FROM 		bi_magic.fact_games
)

SELECT		commander,
			id_game,
			date,
			num_of_players,
			duration,
			winner

FROM		last_games
WHERE		game_order <= 10
ORDER BY	commander,
			game_order



-- =====================================================
-- DEEP-DIVE - COMMANDER METRICS BY STARTING POSITION
-- =====================================================

SELECT		commander,
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



-- =====================================================
-- DEEP-DIVE - WIN RATE BY NUMBER OF PLAYERS
-- =====================================================

SELECT		commander,
			num_of_players,
			ROUND(
			COUNT(*) FILTER(WHERE winner IS TRUE)::numeric /
			NULLIF(COUNT(DISTINCT id_game), 0), 2)			AS win_rate

FROM		bi_magic.fact_games
GROUP BY	commander,
			num_of_players
ORDER BY	commander,
			num_of_players;

			