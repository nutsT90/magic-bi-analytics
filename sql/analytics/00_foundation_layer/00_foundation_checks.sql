-- =====================================================
-- FOUNDATION CHECKS
-- =====================================================



-- =====================================================
-- 1. FACT OVERVIEW
-- =====================================================

SELECT		COUNT(*) 						AS fact_rows,
			COUNT(DISTINCT id_game)			AS distinct_games,
			COUNT(DISTINCT player_name) 	AS distinct_players,
			COUNT(DISTINCT commander)		AS distinct_commanders,
			COUNT(DISTINCT color)			AS distinct_colors,
			MIN(date)						AS first_game_date,
			MAX(date)						AS last_game_date

FROM 		bi_magic.fact_games;



-- =====================================================
-- 2. INVALID GRAIN CASES
-- =====================================================

WITH invalid_grain AS(

	SELECT 		id_game,
				COUNT(*) 						AS rows_in_fact,
				COUNT(DISTINCT player_name)		AS distinct_players,
				COUNT(*) - 
				COUNT(DISTINCT player_name) 	AS duplicated_player_rows
	
	FROM 		bi_magic.fact_games
	GROUP BY	id_game
	HAVING 		COUNT(*) <> COUNT(DISTINCT player_name)
),


-- =====================================================
-- 3. WINNER VALIDATION
-- =====================================================

winner_validation AS(

	SELECT 		id_game,
				COUNT(*) FILTER (WHERE winner IS TRUE)	AS winner_count
	
	FROM 		bi_magic.fact_games
	GROUP BY 	id_game
	HAVING 		COUNT(*) FILTER (WHERE winner IS TRUE) <> 1
),


-- =====================================================
-- 4. DURATION GAME-LEVEL VALIDATION
-- =====================================================

duration_validation AS(

	SELECT 		id_game,
				MAX(EXTRACT(EPOCH FROM duration))	AS max_duration_seconds,
				MIN(EXTRACT(EPOCH FROM duration))	AS min_duration_seconds
				
	FROM 		bi_magic.fact_games
	GROUP BY 	id_game
	HAVING 		MIN(EXTRACT(EPOCH FROM duration)) <> MAX(EXTRACT(EPOCH FROM duration)) 
),


-- =====================================================
-- 5.1. POSITION VALIDATION - 3 PLAYERS
-- =====================================================

position_validation_3p AS(

	SELECT 		id_game,
				num_of_players,
				MIN(position)	AS min_position,
				MAX(position)	AS max_position,
				AVG(position)  	AS avg_position
	FROM 		bi_magic.fact_games
	WHERE 		num_of_players = 3
	GROUP BY	id_game,
				num_of_players
	HAVING		MIN(position) <> 1 OR
				MAX(position) <> 3 OR
				AVG(position) <> 2
),

-- =====================================================
-- 5.2. POSITION VALIDATION - 4 PLAYERS
-- =====================================================

position_validation_4p AS(

	SELECT 		id_game,
				num_of_players,
				COUNT(*) 					AS rows_in_fact,
				COUNT(DISTINCT position) 	AS distinct_positions,
				MIN(position)				AS min_position,
				MAX(position)				AS max_position
	FROM 		bi_magic.fact_games
	WHERE 		num_of_players = 4
	GROUP BY	id_game,
				num_of_players
	HAVING		COUNT(*) NOT IN (4, 5) OR
				COUNT(*) <> COUNT(DISTINCT position) OR
				MIN(position) <> 1 OR
				MAX(position) NOT IN (4, 5)
)


-- =====================================================
-- 6. VALIDATION ISSUE
-- =====================================================

SELECT		id_game, 'grain' 		AS validation_issue 	FROM invalid_grain
UNION ALL
SELECT		id_game, 'winner' 		AS validation_issue 	FROM winner_validation
UNION ALL
SELECT		id_game, 'duration'		AS validation_issue 	FROM duration_validation
UNION ALL	
SELECT 		id_game, '3_players'	AS validation_issue		FROM position_validation_3p
UNION ALL	
SELECT 		id_game, '4_players'	AS validation_issue		FROM position_validation_4p
ORDER BY    id_game, validation_issue;





