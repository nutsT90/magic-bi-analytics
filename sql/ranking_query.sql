DROP TABLE IF EXISTS 	games;
CREATE TEMP TABLE 		games AS

	SELECT 	EXTRACT(YEAR FROM "date")	AS Season,			
			commander 					AS Commander,
			player_name 				AS Player,
			COUNT(*)					AS Matches,
			SUM(
				CASE WHEN winner IS TRUE THEN 1 ELSE 0 END)
										AS Victories

	FROM bi_magic.fact_games
	GROUP BY Season, Commander, Player;
	

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 						ALL SEASON
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++

-- COMMANDERS - ALL
DROP TABLE IF EXISTS 	commanders_all;
CREATE TEMP TABLE 		commanders_all AS

	SELECT 	NULL 			AS Season,
			Commander,
			Player,
			SUM(Matches) 	AS Matches,
			SUM(Victories) 	AS Victories,
			ROUND(SUM(Victories::numeric) / SUM(Matches), 3) 					AS Win_Rate,
			ROW_NUMBER() OVER(ORDER BY SUM(Matches) DESC, Player, Commander) 	AS Ranking_Matches,
			ROW_NUMBER() OVER(ORDER BY SUM(Victories) DESC, Player, Commander) 	AS Ranking_Victories
			
	FROM games
	GROUP BY 1, 2, 3;


-- TOP 15 - COMMANDERS - WIN RATE	
DROP TABLE IF EXISTS 	top_15_commanders_win_rate_all;
CREATE TEMP TABLE		top_15_commanders_win_rate_all AS

	SELECT 	NULL 	AS Season,
			Commander,
			Player,
			Win_Rate
			
	FROM commanders_all
	WHERE Matches >= (SELECT Victories FROM commanders_all WHERE Ranking_Victories = 15) -- Business Rule Filter
	ORDER BY Win_Rate DESC, Player, Commander
	LIMIT 15;


-- PLAYERS - ALL
DROP TABLE IF EXISTS 	players_all;
CREATE TEMP TABLE 		players_all AS

	SELECT 	NULL 			AS Season,
			Player,
			SUM(Matches) 	AS Matches,
			SUM(Victories)	AS Victories,
			ROUND(SUM(Victories::numeric) / SUM(Matches), 3) 		AS Win_Rate,
			ROW_NUMBER() OVER(ORDER BY SUM(Matches) DESC, Player) 	AS Ranking_Matches,
			ROW_NUMBER() OVER(ORDER BY SUM(Victories) DESC, Player)	AS Ranking_Victories

	FROM games
	GROUP BY 1, 2;
	
	
-- TOP 3 - PLAYERS - WIN RATE		
DROP TABLE IF EXISTS 	top_3_players_win_rate_all;
CREATE TEMP TABLE		top_3_players_win_rate_all AS

	SELECT 	NULL 	AS Season,
			Player,
			Win_Rate
			
	FROM players_all
	ORDER BY Win_Rate DESC, Player
	LIMIT 3;


-- ++++++++++++++++++++++++++++++++++++++++++++++++++++
-- 						SEASONS
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++

-- TOP 15 - COMMANDERS - MATCHES AND VICTORIES
DROP TABLE IF EXISTS 	commanders_seasons;
CREATE TEMP TABLE 		commanders_seasons AS

	SELECT 	Season,
			Commander,
			Player,
			SUM(Matches) 	AS Matches,
			SUM(Victories) 	AS Victories,
			ROUND(SUM(Victories::numeric) / SUM(Matches), 3) AS Win_Rate,
			ROW_NUMBER() OVER(PARTITION BY Season ORDER BY SUM(Matches) DESC, Player, Commander) 	AS Ranking_Matches,
			ROW_NUMBER() OVER(PARTITION BY Season ORDER BY SUM(Victories) DESC, Player, Commander) 	AS Ranking_Victories

	FROM games
	GROUP BY 1, 2, 3;


-- TOP 15 - COMMANDERS - WIN RATE	
DROP TABLE IF EXISTS 	top_15_commanders_win_rate_seasons;
CREATE TEMP TABLE		top_15_commanders_win_rate_seasons AS

WITH commanders_win_rate_seasons AS(
	SELECT 	a.Season,
			a.Commander,
			a.Player,
			a.Win_rate,
			ROW_NUMBER() OVER (PARTITION BY a.Season ORDER BY a.Win_Rate DESC, a.Player, a.Commander) AS Ranking
			
	FROM commanders_seasons a
	LEFT JOIN (SELECT Season, Victories FROM commanders_seasons WHERE Ranking_Victories = 15) b
		ON a.Season = b.Season AND a.Matches >= b.Victories -- Business Rule Filter
	WHERE b.Victories IS NOT NULL
	ORDER BY a.Season, Ranking

)

	SELECT 	Season,
			Commander,
			Player,
			Win_rate
			
	FROM commanders_win_rate_seasons
	WHERE Ranking <= 15
	ORDER BY Season, Ranking;


-- TOP 3 - PLAYERS - MATCHES AND VICTORIES
DROP TABLE IF EXISTS 	players_seasons;
CREATE TEMP TABLE 		players_seasons AS

	SELECT 	Season,
			Player,
			SUM(Matches) 	AS Matches,
			SUM(Victories) 	AS Victories,
			ROUND(SUM(Victories::numeric) / SUM(Matches), 3) AS Win_Rate,
			ROW_NUMBER() OVER(PARTITION BY Season ORDER BY SUM(Matches) DESC, Player)	AS Ranking_Matches,
			ROW_NUMBER() OVER(PARTITION BY Season ORDER BY SUM(Victories) DESC, Player) AS Ranking_Victories

	FROM games
	GROUP BY 1, 2;


-- TOP 3 - PLAYERS - WIN RATE	
DROP TABLE IF EXISTS 	top_3_players_win_rate_seasons;
CREATE TEMP TABLE		top_3_players_win_rate_seasons AS

WITH players_win_rate_seasons AS(
	SELECT 	Season,
			Player,
			Win_rate,
			ROW_NUMBER() OVER (PARTITION BY Season ORDER BY Win_Rate DESC, Player) AS Ranking
			
	FROM players_seasons
	ORDER BY Season, Ranking

)

	SELECT 	Season,
			Player,
			Win_rate
			
	FROM players_win_rate_seasons
	WHERE Ranking <= 3
	ORDER BY Season, Ranking;


DROP TABLE IF EXISTS 	bi_magic.ranking_points;
CREATE TABLE 			bi_magic.ranking_points AS

	SELECT 	Season,
			Player,
			COUNT(*) * 2 AS Bonus_Points
			
	FROM(	
		SELECT Season, Player, 'TCM' AS Ranking_Score FROM commanders_all 				WHERE Ranking_Matches <= 15
		UNION ALL
		SELECT Season, Player, 'TCV' AS Ranking_Score FROM commanders_all 				WHERE Ranking_Victories <= 15
		UNION ALL
		SELECT Season, Player, 'TCW' AS Ranking_Score FROM top_15_commanders_win_rate_all
		UNION ALL
		SELECT Season, Player, 'TPM' AS Ranking_Score FROM players_all 					WHERE Ranking_Matches <= 3
		UNION ALL
		SELECT Season, Player, 'TPV' AS Ranking_Score FROM players_all 					WHERE Ranking_Victories <= 3
		UNION ALL
		SELECT Season, Player, 'TPW' AS Ranking_Score FROM top_3_players_win_rate_all
		UNION ALL
		SELECT Season::Text, Player, 'TCM' AS Ranking_Score FROM commanders_seasons 	WHERE Ranking_Matches <= 15
		UNION ALL
		SELECT Season::Text, Player, 'TCV' AS Ranking_Score FROM commanders_seasons 	WHERE Ranking_Victories <= 15
		UNION ALL
		SELECT Season::Text, Player, 'TCW' AS Ranking_Score FROM top_15_commanders_win_rate_seasons
		UNION ALL
		SELECT Season::Text, Player, 'TPM' AS Ranking_Score FROM players_seasons 		WHERE Ranking_Matches <= 3
		UNION ALL
		SELECT Season::Text, Player, 'TPV' AS Ranking_Score FROM players_seasons 		WHERE Ranking_Victories <= 3
		UNION ALL
		SELECT Season::Text, Player, 'TPW' AS Ranking_Score FROM top_3_players_win_rate_seasons
		)
	
	GROUP BY 1, 2
	ORDER BY Season, Player;


DROP TABLE IF EXISTS	games;
DROP TABLE IF EXISTS 	commanders_all;
DROP TABLE IF EXISTS 	top_15_commanders_win_rate_all;
DROP TABLE IF EXISTS 	players_all;
DROP TABLE IF EXISTS 	top_3_players_win_rate_all;
DROP TABLE IF EXISTS	commanders_seasons;
DROP TABLE IF EXISTS	top_15_commanders_win_rate_seasons;
DROP TABLE IF EXISTS	players_seasons;
DROP TABLE IF EXISTS	top_3_players_win_rate_seasons;


SELECT * FROM bi_magic.ranking_points
