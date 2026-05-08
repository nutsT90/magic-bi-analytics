-- =====================================================
-- VIEW - game_level_base
-- =====================================================

-- This view uses the winner row as the representative row for each game.
-- Foundation checks validate that each game has exactly one winner and consistent match-level fields.

CREATE OR REPLACE VIEW bi_magic.vw_game_level_base AS (

	SELECT		id_game 						AS id_game,
				EXTRACT(YEAR FROM date) 		AS season,
				date							AS game_date,
				EXTRACT(EPOCH FROM duration) 	AS duration_seconds,
				player_name 					AS winner_player,
				commander						AS winner_commander,
				color 							AS winner_color,
				num_of_players					AS num_of_players,
				combo							AS combo_game
				
	FROM 		bi_magic.fact_games
	WHERE 		winner IS TRUE
);
