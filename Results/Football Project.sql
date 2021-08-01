# Checking databases
SELECT * FROM countries;
SELECT * FROM leagues;
SELECT * FROM matches
LIMIT 100;

# Adding a results column in the Matches Database
ALTER TABLE matches
ADD home_result varchar(100) AS
(CASE 
WHEN matches.home_team_goal > matches.away_team_goal THEN "Win"
WHEN matches.home_team_goal < matches.away_team_goal THEN "Loss"
ELSE "Draw"
END);

SELECT home_team_goal, away_team_goal,home_result 
FROM matches;

# Group by Date (Year) & League
ALTER TABLE matches
RENAME COLUMN date to match_date;

ALTER TABLE matches
ADD match_year int(100) AS(
EXTRACT(year FROM STR_TO_DATE (match_date,'%m/%d/%Y')));

SELECT match_date, match_year FROM matches;

SELECT match_year as Year, COUNT(match_api_id) as Number_of_Games,l.league_name as League
FROM matches m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY match_year,l.league_name;


# Goals per season by league for T5 Leagues
SELECT season,l.league_name as League, AVG(home_team_goal) as Avg_Home_goals, AVG(away_team_goal) as Avg_Away_goals,
AVG(home_team_goal-away_team_goal) as Avg_Difference_Goals
FROM matches m
INNER JOIN leagues l ON m.country_id = l.country_id
WHERE l.league_name LIKE "%England%" OR
l.league_name LIKE "%Spain%" OR
l.league_name LIKE "%Germany%" OR
l.league_name LIKE "%France%" OR
l.league_name LIKE "%Italy%" 
GROUP BY season,l.league_name;

# Number of Games with 2+ goals 
ALTER TABLE matches
ADD No_of_Goals int (100) AS 
(home_team_goal+away_team_goal);
 
 CREATE VIEW Goals_per_Game AS 
SELECT s.League as League, s.Number_of_Games as Number_of_Games, 
s.Number_of_Games*100/d.Total as Percentage_of_Games, s.No_of_Goals
FROM(SELECT l.league_name as League,COUNT(No_of_Goals) as Number_of_Games, No_of_Goals 
FROM matches m
INNER JOIN leagues l ON m.country_id = l.country_id
WHERE l.league_name LIKE "%England%" OR
l.league_name LIKE "%Spain%" OR
l.league_name LIKE "%Germany%" OR
l.league_name LIKE "%France%" OR
l.league_name LIKE "%Italy%" 
GROUP BY No_of_Goals, l.league_name) s
JOIN ( SELECT COUNT(No_of_Goals) as Total,l.league_name FROM matches m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY l.league_name) d
ON s.League = d.league_name
HAVING No_Of_Goals > 2
ORDER BY 1,4;

SELECT * FROM Goals_per_Game;

SELECT League, SUM(Percentage_of_Games) AS Percent_Of_High_Scoring_Games
FROM Goals_per_Game
GROUP BY League
ORDER BY 2 DESC;


#Grouping by league to see results
CREATE VIEW Result_Percentages AS
SELECT t.Total*100/m.Total as Result_Percentage, m.league_name, t.home_result
FROM(SELECT home_result, Count(home_result) as Total,l.league_name FROM matches m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY  m.home_result, l.league_name) t
JOIN ( SELECT COUNT(home_result) as Total,l.league_name FROM matches m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY l.league_name) m 
ON t.league_name = m.league_name;

# Pivoting the table
SELECT Result_Percentages.league_name,
       SUM(CASE WHEN home_result = 'Win' THEN Result_Percentage ELSE NULL END) AS "Win%",
       SUM(CASE WHEN home_result = 'Draw' THEN Result_Percentage ELSE NULL END) AS "Draw%",
       SUM(CASE WHEN home_result = 'Loss' THEN Result_Percentage ELSE NULL END) AS "Loss%"
FROM Result_Percentages
GROUP BY Result_Percentages.league_name
ORDER BY 2 DESC;


# Finding the home advantage through odds
ALTER TABLE matches_odds
ADD home_result varchar(100) AS
(CASE 
WHEN matches.home_team_goal > matches.away_team_goal THEN "Win"
WHEN matches.home_team_goal < matches.away_team_goal THEN "Loss"
ELSE "Draw"
END);

DELETE FROM matches_odds
WHERE home_result = "Draw";

ALTER TABLE matches_odds
ADD Payout_Home DECIMAL(10,2) AS
(CASE WHEN home_result = 'Win' THEN B365H ELSE 0 END);
ALTER TABLE matches_odds
ADD Payout_Away DECIMAL(10,2) AS
(CASE WHEN home_result = 'Loss' THEN B365A ELSE 0 END);

SELECT Payout_Home,Payout_Away FROM matches_odds;

CREATE VIEW Average_Home_Payout AS
SELECT m.league_name,t.Odds/m.Total as Avg_Home_odds
FROM(SELECT SUM(Payout_Home) as Odds,l.league_name FROM matches_odds m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY l.league_name) t
JOIN (SELECT COUNT(home_result) as Total,l.league_name FROM matches_odds m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY l.league_name) m 
ON t.league_name = m.league_name;

SELECT * FROM Average_Home_Payout;

CREATE VIEW Average_Away_Payout AS
SELECT m.league_name,f.Odds/m.Total as Avg_Away_odds
FROM(SELECT SUM(Payout_Away) as Odds,l.league_name FROM matches_odds m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY l.league_name) f
JOIN (SELECT COUNT(home_result) as Total,l.league_name FROM matches_odds m
INNER JOIN leagues l ON m.country_id = l.country_id
GROUP BY l.league_name) m 
ON f.league_name = m.league_name;

SELECT * FROM Average_Away_Payout;

SELECT h.league_name, h.Avg_Home_odds,a.Avg_Away_odds, (h.Avg_Home_odds-a.Avg_Away_odds) as Difference
FROM Average_Home_Payout h
JOIN Average_Away_Payout a ON h.league_name = a.league_name
ORDER BY 4 DESC;

