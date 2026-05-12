DROP TABLE IF EXISTS 	bi_magic.players_streak;
CREATE TABLE 			bi_magic.players_streak AS

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 				BASE GAMES AND PREVIOUS WINNER
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++

WITH base_games AS(

SELECT 		id_game,
			player_name,
			winner,
			LAG(winner) OVER (PARTITION BY player_name ORDER BY id_game) AS previous_winner

FROM 		bi_magic.fact_games
),

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 				BASE ALL PLAYERS
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++

all_players AS(

SELECT 		DISTINCT player_name

FROM 		bi_magic.dim_player
),

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 				FIND WHERE STREAK BEGINS
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
streak_start_flags AS( 

SELECT 		id_game,
			player_name,
			winner,
			previous_winner,
			CASE
				WHEN winner IS FALSE THEN 0
				WHEN winner = previous_winner THEN 0
				ELSE 1
			END AS start_win_streak,
			CASE
				WHEN winner IS TRUE THEN 0
				WHEN winner = previous_winner THEN 0
				ELSE 1
			END AS start_lose_streak

FROM 		base_games
),

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 			RUNNING SUM CREATES STREAK BLOCKS
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
streak_blocks AS(

SELECT 		id_game,
			player_name,
			winner,
			previous_winner,
			start_win_streak,
			start_lose_streak,
			SUM(start_win_streak) OVER (PARTITION BY player_name ORDER BY id_game) 	AS win_streak,
			SUM(start_lose_streak) OVER (PARTITION BY player_name ORDER BY id_game) 	AS lose_streak

FROM 		streak_start_flags
),

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 					CURRENT STREAK
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
current_streak_base AS(

SELECT 		id_game,
			player_name,
			winner,
			COUNT(win_streak) OVER (PARTITION BY player_name, winner, win_streak ORDER BY id_game) AS current_streak
			-- current_streak works for win and lose situations

FROM 		streak_blocks 
),

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 			GET CURRENT STREAK FROM LAST GAME
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
current_streak_final AS(

SELECT   	a.player_name,
			CASE 
				WHEN a.winner IS TRUE THEN 'Victory'
				ELSE 'Defeat'
			END 				AS current_streak_type,
			a.current_streak 	AS current_streak_value

FROM 		current_streak_base a
INNER JOIN
			(
			SELECT		player_name,
						MAX(id_game) AS max_id_game
			
			FROM 		current_streak_base
			GROUP BY 	player_name
			) b
			
			ON a.player_name = b.player_name AND a.id_game = b.max_id_game
),

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 				AGGREGATING STREAK BLOCKS
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
streak_agg AS(

SELECT 		player_name,
			win_streak,
			lose_streak,
			COUNT(CASE WHEN winner IS TRUE THEN win_streak END) 	AS count_win_streak,
			COUNT(CASE WHEN winner IS FALSE THEN lose_streak END) 	AS count_lose_streak

FROM 		streak_blocks
GROUP BY 	player_name, win_streak, lose_streak
),

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 					LONGEST STREAKS
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
final_streaks AS(
SELECT 		player_name,
			MAX(count_win_streak) 	AS max_win_streak,
			MAX(count_lose_streak)	AS max_lose_streak

FROM 		streak_agg
GROUP BY	player_name
)

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 					FINAL QUERY
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++


	SELECT 		a.player_name,
				b.max_win_streak,
				b.max_lose_streak,
				c.current_streak_type,
				c.current_streak_value
				
	
	FROM 		all_players a
	LEFT JOIN	final_streaks b ON a.player_name = b.player_name
	LEFT JOIN	current_streak_final c ON a.player_name = c.player_name
	ORDER BY 	a.player_name;


SELECT * FROM bi_magic.players_streak;

