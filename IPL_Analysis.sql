Team Performance Analysis
-- Q1. Which team has won the most IPL titles?
SELECT WINNER, COUNT(*)AS TOTAL_WINS
FROM MATCHES
WHERE MATCH_TYPE ='FINAL' OR RESULT IS NOT NULL
GROUP BY WINNER
ORDER BY TOTAL_WINS DESC
-- Q2. Win rate by team (home vs away analysis)
SELECT
	TEAM1 AS TEAM,
	COUNT(*) AS TOTAL_MATCHES,
	SUM(CASE WHEN WINNER = TEAM1 THEN 1 ELSE 0 END) AS WINS,
	ROUND(100*SUM(CASE WHEN WINNER = TEAM1 THEN 1 ELSE 0 END)/COUNT(*),2)AS WIN_RATE_PCT
	FROM MATCHES
	GROUP BY TEAM1
	ORDER BY WIN_RATE_PCT DESC

-- Q3. Toss impact — does winning the toss help win the match?
SELECT
	TOSS_DECISION,
	COUNT(*) AS TOTAL_MATCHES,
	SUM(CASE WHEN TOSS_WINNER=WINNER THEN 1 ELSE 0 END)AS TOSS_WINNER_WON,
	ROUND(100*SUM(CASE WHEN TOSS_WINNER=WINNER THEN 1 ELSE 0 END)/COUNT(*),2)AS WIN_PCT
	FROM MATCHES
	GROUP BY TOSS_DECISION

Player Performance Analysis
-- Q4. Top 10 run scorers of all time
SELECT
	BATTER,
	SUM(BATSMAN_RUNS) AS TOTAL_RUNS,
	COUNT(DISTINCT MATCH_ID) AS MATCHES_PLAYED,
	ROUND(SUM(BATSMAN_RUNS)*1/COUNT(DISTINCT MATCH_ID),2) AS AVG_RUNS_PER_MATCH
	FROM DELIVERIES
	GROUP BY BATTER
	ORDER BY TOTAL_RUNS DESC
	OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q5. Top 10 wicket takers of all time
SELECT
	BOWLER,
	COUNT(*) AS TOTAL_WICKETS,
	COUNT(distinct match_id) as matches_played,
	ROUND(COUNT(*)*1/COUNT(DISTINCT MATCH_ID),2) AS WICKETS_PER_MATCH
	FROM DELIVERIES
	WHERE player_dismissed IS NOT NULL AND dismissal_kind NOT IN('RUN OUT','RETIRED HURT','OBSTRUCTING THE FIELD')
	GROUP BY bowler
	ORDER BY TOTAL_WICKETS DESC
	OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q6. Player of the Match frequency
SELECT 
    player_of_match,
    COUNT(*) AS awards,
    COUNT(DISTINCT season) AS seasons_active
FROM matches
WHERE player_of_match IS NOT NULL
GROUP BY player_of_match
ORDER BY awards DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q7. Strike rate of top batters (minimum 500 balls faced)
SELECT 
    batter,
    SUM(batsman_runs) AS total_runs,
    COUNT(*) AS balls_faced,
    cast(ROUND(SUM(batsman_runs) * 100.0 / COUNT(*), 2)AS DECIMAL(10,2)) AS strike_rate
FROM deliveries
WHERE extras_type NOT IN ('wides', 'noballs') 
   OR extras_type IS NULL
GROUP BY batter
HAVING COUNT(*) >= 500
ORDER BY strike_rate DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

Season Trends
-- Q8. Total runs per season with year-on-year change
SELECT 
    m.season,
    SUM(d.total_runs) AS total_runs,
    SUM(d.total_runs) - LAG(SUM(d.total_runs)) OVER (ORDER BY m.season) AS yoy_change
FROM deliveries d
JOIN matches m ON d.match_id = m.id
GROUP BY m.season
ORDER BY m.season

-- Q9. Cumulative wins per team per season
SELECT 
    season,
    winner,
    COUNT(*) AS season_wins,
    SUM(COUNT(*)) OVER (PARTITION BY winner ORDER BY season) AS cumulative_wins
FROM matches
WHERE winner IS NOT NULL
GROUP BY season, winner
ORDER BY winner, season

-- Q10. Rank teams by wins within each season
SELECT 
    season,
    winner AS team,
    COUNT(*) AS wins,
    RANK() OVER (PARTITION BY season ORDER BY COUNT(*) DESC) AS season_rank
FROM matches
WHERE winner IS NOT NULL AND winner != 'NA'
GROUP BY season, winner
ORDER BY season, season_rank

Venue Intelligence

-- Q11. Venues that favor batting (highest average runs per match)
SELECT 
    m.venue,
    COUNT(DISTINCT m.id) AS matches_played,
    ROUND(SUM(d.total_runs) * 1.0 / COUNT(DISTINCT m.id), 2) AS avg_runs_per_match
FROM matches m
JOIN deliveries d ON m.id = d.match_id
GROUP BY m.venue
HAVING COUNT(DISTINCT m.id) >= 10
ORDER BY avg_runs_per_match DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q12. Toss decision preference by venue
SELECT 
    venue,
    toss_decision,
    COUNT(*) AS times_chosen
FROM matches
GROUP BY venue, toss_decision
ORDER BY venue, times_chosen DESC

-- Q13. Death over specialists (overs 16-20)
WITH death_overs AS (
    SELECT 
        bowler,
        COUNT(*) AS balls_bowled,
        SUM(total_runs) AS runs_conceded,
        COUNT(CASE WHEN is_wicket = 1
                   AND dismissal_kind NOT IN ('run out','retired hurt') 
                   THEN 1 END) AS wickets
    FROM deliveries
    WHERE OVERS BETWEEN 16 AND 20
    GROUP BY bowler
    HAVING COUNT(*) >= 120
)
SELECT 
    bowler,
    balls_bowled,
    runs_conceded,
    wickets,
    ROUND(runs_conceded * 6.0 / balls_bowled, 2) AS economy_rate
FROM death_overs
ORDER BY economy_rate ASC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q14. Powerplay run rate by team (overs 1-6)
WITH powerplay AS (
    SELECT 
        batting_team,
        match_id,
        SUM(total_runs) AS pp_runs
    FROM deliveries
    WHERE overs BETWEEN 1 AND 6
    GROUP BY batting_team, match_id
)
SELECT 
    batting_team,
    COUNT(match_id) AS innings,
    ROUND(AVG(pp_runs), 2) AS avg_powerplay_runs
FROM powerplay
GROUP BY batting_team
ORDER BY avg_powerplay_runs DESC;

-- Q15. Most consistent batters
WITH batter_scores AS (
    SELECT 
        batter,
        match_id,
        SUM(batsman_runs) AS match_runs
    FROM deliveries
    GROUP BY batter, match_id
    HAVING SUM(batsman_runs) > 0
)
SELECT 
    batter,
    COUNT(match_id) AS innings,
    ROUND(AVG(match_runs), 2) AS avg_score,
    ROUND(STDEV(match_runs), 2) AS consistency_score
FROM batter_scores
GROUP BY batter
HAVING COUNT(match_id) >= 50
ORDER BY consistency_score ASC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q16. Head-to-head: Mumbai Indians vs CSK
WITH h2h AS (
    SELECT 
        winner
    FROM matches
    WHERE (team1 = 'Mumbai Indians' AND team2 = 'Chennai Super Kings')
       OR (team1 = 'Chennai Super Kings' AND team2 = 'Mumbai Indians')
)
SELECT 
    winner,
    COUNT(*) AS wins
FROM h2h
GROUP BY winner

-- Q17. Boundary percentage per batter
SELECT 
    batter,
    SUM(batsman_runs) AS total_runs,
    SUM(CASE WHEN batsman_runs IN (4, 6) THEN batsman_runs ELSE 0 END) AS boundary_runs,
    ROUND(100.0 * SUM(CASE WHEN batsman_runs IN (4, 6) THEN batsman_runs ELSE 0 END)
          / NULLIF(SUM(batsman_runs), 0), 2) AS boundary_pct
FROM deliveries
GROUP BY batter
HAVING SUM(batsman_runs) >= 500
ORDER BY boundary_pct DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q18. Most successful chasing teams
SELECT 
    winner,
    COUNT(*) AS successful_chases
FROM matches
WHERE result = 'runs' AND winner IS NOT NULL
GROUP BY winner
ORDER BY successful_chases DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY

-- Q19. Season-wise Player of the Match leaders
WITH potm_ranked AS (
    SELECT 
        season,
        player_of_match,
        COUNT(*) AS awards,
        RANK() OVER (PARTITION BY season ORDER BY COUNT(*) DESC) AS rnk
    FROM matches
    WHERE player_of_match IS NOT NULL
    GROUP BY season, player_of_match
)
SELECT season, player_of_match, awards
FROM potm_ranked
WHERE rnk = 1
ORDER BY season

-- Q20. Franchise value score (composite metric)
WITH team_stats AS (
    SELECT 
        winner AS team,
        COUNT(*) AS total_wins,
        SUM(CASE WHEN result = 'runs' THEN result_margin ELSE 0 END) AS total_run_margin,
        SUM(CASE WHEN result = 'wickets' THEN result_margin ELSE 0 END) AS total_wicket_margin
    FROM matches
    WHERE winner IS NOT NULL
    GROUP BY winner
)
SELECT 
    team,
    total_wins,
    ROUND(total_wins * 1.0 + total_run_margin * 0.01 + total_wicket_margin * 0.5, 2) AS franchise_value_score
FROM team_stats
ORDER BY franchise_value_score DESC