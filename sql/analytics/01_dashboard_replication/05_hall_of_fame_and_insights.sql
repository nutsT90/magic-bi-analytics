-- =====================================================
-- HALL OF FAME
-- =====================================================

WITH players_base AS(

	SELECT		a.player_name,
				COUNT(DISTINCT a.id_game) 							AS matches,
				COUNT(a.*) FILTER(WHERE a.winner IS TRUE)			AS victories,
				ROUND(
				COUNT(a.*) FILTER(WHERE a.winner IS TRUE)::numeric /
				NULLIF(COUNT(DISTINCT a.id_game), 0), 2)			AS win_rate,
				MIN(a.duration) FILTER(WHERE a.winner IS TRUE)		AS fastest_victory,
				MAX(max_win_streak)									AS max_win_streak,
				COUNT(a.*) FILTER(WHERE a.combo IS TRUE)			AS combos
				
				
	
	FROM		bi_magic.fact_games a
	LEFT JOIN	bi_magic.players_streak b ON a.player_name = b.player_name
	GROUP BY	a.player_name
),

commanders_base AS(

	SELECT		a.commander,
				COUNT(DISTINCT a.id_game) 							AS matches,
				COUNT(a.*) FILTER(WHERE a.winner IS TRUE)			AS victories,
				ROUND(
				COUNT(a.*) FILTER(WHERE a.winner IS TRUE)::numeric /
				NULLIF(COUNT(DISTINCT a.id_game), 0), 2)			AS win_rate,
				MIN(a.duration) FILTER(WHERE a.winner IS TRUE)		AS fastest_victory,
				MAX(max_win_streak)									AS max_win_streak,
				COUNT(a.*) FILTER(WHERE a.combo IS TRUE)			AS combos
				
				
	
	FROM		bi_magic.fact_games a
	LEFT JOIN	bi_magic.commanders_streak b ON a.commander = b.commander
	GROUP BY	a.commander
),

players_ranking AS(

	SELECT		'player' 									AS category,
				player_name,
				RANK() OVER(ORDER BY matches DESC)			AS ranking_matches,
				RANK() OVER(ORDER BY victories DESC)		AS ranking_victories,
				RANK() OVER(ORDER BY 
								CASE
									WHEN matches < 5 THEN NULL
									ELSE win_rate 
								END
							DESC NULLS LAST)				AS ranking_win_rate,
				RANK() OVER(ORDER BY fastest_victory ASC)	AS ranking_fastest_victory,
				RANK() OVER(ORDER BY max_win_streak DESC)	AS ranking_max_win_streak,
				RANK() OVER(ORDER BY combos DESC)			AS ranking_combos
					
	FROM		players_base

	
),

commanders_ranking AS(

	SELECT		'commander' 								AS category,
				commander,
				RANK() OVER(ORDER BY matches DESC)			AS ranking_matches,
				RANK() OVER(ORDER BY victories DESC)		AS ranking_victories,
				RANK() OVER(ORDER BY 
								CASE
									WHEN matches < 5 THEN NULL
									ELSE win_rate 
								END
							DESC NULLS LAST)				AS ranking_win_rate,
				RANK() OVER(ORDER BY fastest_victory ASC)	AS ranking_fastest_victory,
				RANK() OVER(ORDER BY max_win_streak DESC)	AS ranking_max_win_streak,
				RANK() OVER(ORDER BY combos DESC)			AS ranking_combos
					
	FROM		commanders_base
),

hall_of_fame AS(

	SELECT		b.category, a.player_name AS entity_name, 'Most Matches' AS fame, a.matches::text AS metric_value
	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	WHERE 		b.ranking_matches = 1
	
	UNION ALL
	
	SELECT		b.category, a.player_name AS entity_name, 'Most Victories' AS fame, a.victories::text AS metric_value
	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	WHERE 		b.ranking_victories = 1
	
	UNION ALL
	
	SELECT		b.category, a.player_name AS entity_name, 'Best Win Rate' AS fame, a.win_rate::text AS metric_value
	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	WHERE 		b.ranking_win_rate = 1
	
	UNION ALL
	
	SELECT		b.category, a.player_name AS entity_name, 'Fastest Victory' AS fame, a.fastest_victory::text AS metric_value
	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	WHERE 		b.ranking_fastest_victory = 1
	
	UNION ALL
	
	SELECT		b.category, a.player_name AS entity_name, 'Longest Win Streak' AS fame, a.max_win_streak::text AS metric_value
	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	WHERE 		b.ranking_max_win_streak = 1
	
	UNION ALL
	
	SELECT		b.category, a.player_name AS entity_name, 'Most Combos' AS fame, a.combos::text AS metric_value
	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	WHERE 		b.ranking_combos = 1
	
	UNION ALL
	
	SELECT		b.category, a.commander AS entity_name, 'Most Matches' AS fame, a.matches::text AS metric_value
	FROM		commanders_base a
	LEFT JOIN	commanders_ranking b ON a.commander = b.commander
	WHERE 		b.ranking_matches = 1
	
	UNION ALL
	
	SELECT		b.category, a.commander AS entity_name, 'Most Victories' AS fame, a.victories::text AS metric_value
	FROM		commanders_base a
	LEFT JOIN	commanders_ranking b ON a.commander = b.commander
	WHERE 		b.ranking_victories = 1
	
	UNION ALL
	
	SELECT		b.category, a.commander AS entity_name, 'Best Win Rate' AS fame, a.win_rate::text AS metric_value
	FROM		commanders_base a
	LEFT JOIN	commanders_ranking b ON a.commander = b.commander
	WHERE 		b.ranking_win_rate = 1
	
	UNION ALL
	
	SELECT		b.category, a.commander AS entity_name, 'Fastest Victory' AS fame, a.fastest_victory::text AS metric_value
	FROM		commanders_base a
	LEFT JOIN	commanders_ranking b ON a.commander = b.commander
	WHERE 		b.ranking_fastest_victory = 1
	
	UNION ALL
	
	SELECT		b.category, a.commander AS entity_name, 'Longest Win Streak' AS fame, a.max_win_streak::text AS metric_value
	FROM		commanders_base a
	LEFT JOIN	commanders_ranking b ON a.commander = b.commander
	WHERE 		b.ranking_max_win_streak = 1
	
	UNION ALL
	
	SELECT		b.category, a.commander AS entity_name, 'Most Combos' AS fame, a.combos::text AS metric_value
	FROM		commanders_base a
	LEFT JOIN	commanders_ranking b ON a.commander = b.commander
	WHERE 		b.ranking_combos = 1
),

-- =====================================================
-- INSIGHTS
-- =====================================================

-- =====================================================
-- 1. Volume leaders are not efficiency leaders
-- =====================================================

score AS(

	SELECT 		player_name,
				COUNT(DISTINCT id_game) 											AS M,  -- Match Points
				COUNT(*) FILTER(WHERE winner IS TRUE AND num_of_players = 3) * 4	AS V3, -- Victory 3p Points
				COUNT(*) FILTER(WHERE winner IS TRUE AND num_of_players >= 4) * 5	AS V4, -- Victory 4p Points
				COUNT(*) FILTER(WHERE combo IS TRUE) * - 3							AS C   -- Combo Penalty

	FROM 		bi_magic.fact_games
	GROUP BY	player_name
),

insight_1 AS(

	SELECT 		a.player_name,
				a.matches,
				b.ranking_matches,
				a.win_rate,
				b.ranking_win_rate

	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	ORDER BY	b.ranking_matches

),



-- =====================================================
-- 2. Efficiency alone does not define the leaderboard
-- =====================================================

insight_2 AS(

	SELECT 		a.player_name,
				a.matches,
				a.win_rate,
				b.ranking_win_rate,
				c.M + c.V3 + c.V4 + c.C	AS base_score

	FROM		players_base a
	LEFT JOIN	players_ranking b ON a.player_name = b.player_name
	LEFT JOIN	score c ON a.player_name = c.player_name
	ORDER BY	b.ranking_win_rate
),



-- =====================================================
-- 3. Going first is not always the advantage
-- =====================================================

insight_3 AS(

	SELECT		num_of_players,
				CASE
					WHEN position = 5 THEN 4
					ELSE position
				END 										AS starting_position,
				COUNT(DISTINCT id_game) 					AS matches,
				COUNT(*) FILTER(WHERE winner IS TRUE)		AS victories,
				ROUND(
				COUNT(*) FILTER(WHERE winner IS TRUE)::numeric /
				NULLIF(COUNT(DISTINCT id_game), 0), 2)			AS win_rate
				
	
	FROM 		bi_magic.fact_games
	GROUP BY	1, 2
	ORDER BY	1, 2
),



-- =====================================================
-- 4. Combo wins are relatively rare
-- =====================================================

insight_4 AS(

	SELECT 		player_name,
				victories,
				combos,
				ROUND(
					combos::numeric / 
					NULLIF(victories, 0) 
				, 2) 						AS combo_share

	FROM		players_base
	ORDER BY	4 DESC NULLS LAST
),



-- =====================================================
-- 5. Base points drive most of the score
-- =====================================================

insight_5 AS(

	SELECT		a.player_name,
				a.M + a.V3 + a.V4 + a.C	+
				COALESCE(b.bonus_points, 0)	AS total_score,
				a.M + a.V3 + a.V4 + a.C		AS base_score,
				COALESCE(b.bonus_points, 0)	AS bonus_points,
				ROUND(
					(a.M + a.V3 + a.V4 + a.C)::numeric /
					NULLIF((a.M + a.V3 + a.V4 + a.C + COALESCE(b.bonus_points, 0)), 0)
				, 2)						AS share_base_score
				

	FROM		score a
	LEFT JOIN	bi_magic.ranking_points b ON a.player_name = b.player AND b.season IS NULL
	ORDER BY	5 ASC
),



-- =====================================================
-- 6. Three-color-plus decks dominate the meta
-- =====================================================

insight_6 AS(

	SELECT		CASE
					WHEN b.color_group::int >= 3 THEN '3+'
					ELSE b.color_group
				END 						AS color_group,
				COUNT(a.*) 					AS deck_appearances,
				COUNT(DISTINCT a.id_game)	AS distinct_games_present

	FROM		bi_magic.fact_games a
	LEFT JOIN	bi_magic.dim_color b ON a.color = b.color
	GROUP BY 	1
	ORDER BY	2 DESC

)

SELECT * FROM hall_of_fame;

-- To validate each insight, run:
-- SELECT * FROM insight_1;
-- SELECT * FROM insight_2;
-- SELECT * FROM insight_3;
-- SELECT * FROM insight_4;
-- SELECT * FROM insight_5;
-- SELECT * FROM insight_6;
