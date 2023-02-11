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
  yearid / 10 * 10 AS decade_start,
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
INNER JOIN people 
USING(playerid)
ORDER BY success DESC
LIMIT 1;

-- Chris Owings had the most success with 21/23 stolen bases or 91%

-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series?  

SELECT 
  MAX(CASE WHEN wswin = 'N' THEN w END) AS most_wins_no_ws,
  MIN(CASE WHEN wswin = 'Y' THEN w END) AS least_wins_ws
FROM teams
WHERE yearid BETWEEN 1970 AND 2016;

-- 116 is the largest number of wins for a team that did not win the world series while 63 is the smallest number of wins for a team that did win the world series. 

-- Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year.

SELECT
MAX(CASE WHEN wswin = 'N' THEN w END) AS most_wins_no_ws,
MIN(CASE WHEN wswin = 'Y' THEN w END) AS least_wins_ws
FROM teams
WHERE yearid BETWEEN 1970 AND 2016 AND yearid != 1981;

-- Removing the year 1981 yields 83 as the smallest number of wins for a team that did win the world series.

-- How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

SELECT SUM(CASE WHEN t.w = (SELECT MAX(w) 
							FROM teams WHERE yearid = t.yearid) 
		   					AND t.wswin = 'Y' 
		                    THEN 1 ELSE 0 END) AS total_years
FROM teams AS t
WHERE t.yearid BETWEEN 1970 AND 2016;

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
wswin = 'Y' AND w = (SELECT MAX(w) 
	 				 FROM teams 
					 WHERE yearid = t.yearid 
					 AND yearid != 1994);

-- About 26% of the time. There was no World Series in 1994 due to a strike.

-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

SELECT DISTINCT people.namefirst,
				people.namelast,
				teams.name AS team_name,
				awardsmanagers.yearid
FROM awardsmanagers
INNER JOIN people
	USING(playerid)
INNER JOIN managers
	USING(playerid, yearid)
INNER JOIN teams
	USING(yearid, teamid)
WHERE
awardsmanagers.awardid = 'TSN Manager of the Year' AND
awardsmanagers.lgid IN ('NL', 'AL') 
ORDER BY
awardsmanagers.yearid;

-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.

SELECT namefirst, 
	   namelast,
       SUM(so) AS strikeouts,
       salary::numeric::money AS total_salary,
       salary::numeric::money / SUM(so) AS so_cost
FROM pitching
LEFT JOIN salaries
	USING(playerid)
LEFT JOIN people
	USING(playerid)
WHERE pitching.yearid = 2016 AND gs >= 10 AND salaries.yearid = 2016
GROUP BY total_salary, namefirst, namelast
ORDER BY so_cost DESC;

-- Matt Cain had the highest cost per strikeout at $289,351.84.

-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.

SELECT namefirst,
	   namelast,
	   SUM(h) AS total_hits,
       halloffame.yearid,
       CASE WHEN inducted = 'N' THEN NULL ELSE inducted END AS inducted
FROM batting
LEFT JOIN people
	USING(playerid)
LEFT JOIN halloffame
	USING(playerid)
GROUP BY playerid, namefirst, namelast, halloffame.yearid, inducted
HAVING SUM(h) >= 3000
ORDER BY total_hits DESC;

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.

SELECT namefirst,
	   namelast, 
	   SUM(h) AS total_hits
FROM batting
LEFT JOIN people
	USING(playerid)
GROUP BY namefirst, namelast
HAVING count(distinct teamID) = 2 AND sum(h) >= 1000;

WITH two_teams AS (
	SELECT playerID, teamID, sum(h) as total_hits
	FROM batting
	GROUP BY playerID, teamID
	HAVING sum(h) >= 1000)
SELECT namefirst, namelast
FROM two_teams
LEFT JOIN people 
USING(playerID)
GROUP BY playerid, namefirst, namelast
HAVING COUNT(DISTINCT teamID) = 2;

-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

SELECT namefirst, 
	   namelast, 
	   SUM(CASE WHEN yearid = 2016 THEN hr ELSE 0 END) AS homeruns_2016
FROM batting
INNER JOIN people 
USING(playerID)
GROUP BY namefirst, namelast
HAVING COUNT(DISTINCT yearid) >= 10 AND
       SUM(hr) = MAX(CASE WHEN yearid = 2016 THEN hr ELSE 0 END) AND
       SUM(hr) > 0;
	   
-- Not sure if this is correct but this query only returned one result - Bartolo Colon with 1 home run in 2016.

-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

SELECT yearid, teamid, SUM(salary::numeric::money) AS team_salary
FROM salaries
WHERE yearid >= 2000
GROUP BY yearid, teamid
ORDER BY yearid;

WITH team_salaries AS (
  SELECT yearid, teamid, SUM(salary::numeric::money) AS team_salary
  FROM salaries
  WHERE yearid >= 2000
  GROUP BY yearid, teamid
  ORDER BY yearid
)
SELECT team_salaries.yearid, 
       teamid, 
       team_salary, 
       SUM(teams.w) AS total_wins
FROM team_salaries
INNER JOIN teams 
USING(teamid)
GROUP BY team_salaries.yearid, 
         teamid, 
         team_salary
ORDER BY team_salaries.yearid;

-- After running the corr() function in Python, overall there seems to be a low positive correlation of 0.31. 

-- Correlations by year:
-- 2000: 0.1440853821499386 
-- 2001: 0.2608180479382707 
-- 2002: 0.19642317910515142 
-- 2003: 0.22284553250191663 
-- 2004: 0.30365070216547463 
-- 2005: 0.40935671929136264 
-- 2006: 0.44944136583692906 
-- 2007: 0.44494182713975655 
-- 2008: 0.4604057185764303 
-- 2009: 0.4353123961518359 
-- 2010: 0.4816556217627416 
-- 2011: 0.4580469838751553 
-- 2012: 0.3467816061450339 
-- 2013: 0.42038404667963425 
-- 2014: 0.28915673888915705 
-- 2015: 0.3378948591543174 
-- 2016: 0.2665364569788023

-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?  

SELECT yearid, teamid, w, attendance
FROM teams
WHERE yearid >= 1890
GROUP BY yearid, teamid, w, attendance
ORDER BY yearid;

-- Overall, since 1890 when attendance data was first made available, there is a moderate positive correlation of 0.4

--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.

WITH attendance_boost AS (
  SELECT 
		teamid, yearid, attendance,
        LAG(attendance) OVER(
			 		PARTITION BY teamid 
			 		ORDER BY yearid) AS prior_attendance
  FROM teams
)
SELECT 
	CASE WHEN t.wswin = 'Y' THEN 'World Series Winner'
    WHEN t.divwin = 'Y' THEN 'Division Winner'
    WHEN t.wcwin = 'Y' THEN 'Wild Card Winner'
    ELSE 'No Chamionship Win' END AS championship,
    ROUND(AVG(ab.attendance - ab.prior_attendance)) AS avg_attendance_boost
FROM attendance_boost AS ab
INNER JOIN teams AS t
ON ab.teamid = t.teamid AND ab.yearid = t.yearid + 1
GROUP BY championship
ORDER BY avg_attendance_boost DESC;

-- Teams that win the world series see an average attendance boost the following year of 16,482. Whereas teams that are wild card winners see an average boost of 97,548. Division winners - 22,233 and no championship win - 12,660.

-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?