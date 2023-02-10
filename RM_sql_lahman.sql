-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?

SELECT namefirst,
	   namelast,
       SUM(salary)::numeric::money AS total_salary
FROM people
INNER JOIN (
SELECT DISTINCT playerid
FROM collegeplaying
WHERE schoolid = 'vandy'
) AS v
USING(playerid)
INNER JOIN salaries
USING(playerid)
GROUP BY playerid, namefirst, namelast
ORDER BY total_salary DESC;

-- David Price earned the most money with $81,851,296.00

-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

SELECT 
  CASE WHEN pos IN ('OF') THEN 'Outfield'
       WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
       WHEN pos IN ('P', 'C') THEN 'Battery'
  	   END AS position,
  SUM(po) AS putouts_2016
FROM fielding
WHERE yearid = 2016
GROUP BY position;


-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)

SELECT 
  (yearid / 10) * 10 AS decade_start,
  ROUND(AVG(so / g),2) AS avg_strikeouts,
  ROUND(AVG(hr / g),2) AS avg_homeruns
FROM teams
WHERE yearid >= 1920 AND yearid <= 2016
GROUP BY decade_start
ORDER BY decade_start;
	
-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.

WITH stolen_bases AS (
  SELECT playerid, sb, cs, ROUND(sb * 1.0 / (sb + cs),2) AS success
  FROM batting
  WHERE yearid = 2016 AND sb + cs >= 20
)
SELECT namefirst,
	   namelast,
	   sb, 
	   sb + cs AS attempts, 
	   success
FROM stolen_bases
JOIN people 
USING(playerid)
ORDER BY success DESC
LIMIT 1;

-- Chris Owings had the most success with 21/23 stolen bases or 91%

-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year. 

SELECT
  MAX(CASE WHEN wswin = 'N' THEN w END) AS most_wins_no_ws,
  MIN(CASE WHEN wswin = 'Y' THEN w END) AS least_wins_ws
FROM teams
WHERE yearid BETWEEN 1970 AND 2016;

-- 116 is the largest number of wins for a team that did not win the world series while 63 is the smallest number of wins for a team that did win the world series. 

-- How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

SELECT SUM(CASE WHEN t.w = (SELECT MAX(w) 
							FROM teams WHERE yearid = t.yearid 
							AND yearid != 1994) AND t.wswin = 'Y' 
		                    THEN 1 ELSE 0 END) AS total_years
FROM teams AS t
WHERE t.yearid BETWEEN 1970 AND 2016 AND t.yearid != 1994;

-- 12 years

SELECT
	ROUND(100.0 * COUNT(*)/ (SELECT COUNT(DISTINCT yearid)
	FROM teams WHERE yearid BETWEEN 1970 AND 2016
	AND yearid != 1994), 2)
FROM (
SELECT yearid, w, wswin
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND yearid != 1994
) AS t
WHERE
wswin = 'Y' AND
w = (SELECT MAX(w) 
	 FROM teams WHERE yearid = t.yearid AND yearid != 1994);

-- About 26% of the time. There was no World Series in 1994 due to a strike.

-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

SELECT *
FROM awardsmanagers
WHERE
awardsmanagers.awardid = 'TSN Manager of the Year' AND
awardsmanagers.lgid IN ('NL', 'AL');

SELECT DISTINCT
people.namefirst,
people.namelast,
yearid
FROM awardsmanagers
INNER JOIN people 
ON awardsmanagers.playerid = people.playerid
WHERE
awardsmanagers.awardid = 'TSN Manager of the Year' AND
awardsmanagers.lgid IN ('NL', 'AL')
ORDER BY yearid;

SELECT DISTINCT
people.namefirst,
people.namelast,
teams.name AS team_name,
awardsmanagers.yearid
FROM awardsmanagers
INNER JOIN managers 
	ON awardsmanagers.playerid = managers.playerid
INNER JOIN teams 
	ON managers.teamid = teams.teamid
INNER JOIN people 
	ON awardsmanagers.playerid = people.playerid
WHERE
awardsmanagers.awardid = 'TSN Manager of the Year' AND
awardsmanagers.lgid IN ('NL', 'AL') AND
awardsmanagers.yearid = managers.yearid
ORDER BY
awardsmanagers.yearid;


-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.

-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.

-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?  
--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?

SELECT *
FROM teams;