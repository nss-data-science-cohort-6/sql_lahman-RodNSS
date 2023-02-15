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
WHERE yearid BETWEEN 1970 AND 2016

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
FROM pitching p
LEFT JOIN salaries AS s
	USING(playerid)
LEFT JOIN people
	USING(playerid)
WHERE p.yearid = 2016 AND gs >= 10 AND s.yearid = 2016
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

WITH two_teams AS (
	SELECT playerID, teamID, sum(h) AS total_hits
	FROM batting
	GROUP BY playerID, teamID
	HAVING SUM(h) >= 1000)
SELECT namefirst || ' ' || namelast AS name
FROM two_teams
LEFT JOIN people 
USING(playerID)
GROUP BY playerid, name
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

WITH pitchers AS (
  SELECT 
    CASE WHEN throws = 'L' THEN 'Left' ELSE 'Right' END AS throwing_arm,
    COUNT(playerID) AS total_pitchers
  FROM people
  GROUP BY throwing_arm
)
SELECT throwing_arm, 
       total_pitchers, 
       ROUND(total_pitchers * 100.0 / SUM(total_pitchers) OVER ()) AS percentage
FROM pitchers;

-- 19% of pitchers are left handed.

-- Bonus Questions

-- 1. In this question, you'll get to practice correlated subqueries and learn about the LATERAL keyword. Note: This could be done using window functions, but we'll do it in a different way in order to revisit correlated subqueries and see another keyword - LATERAL.

-- a. First, write a query utilizing a correlated subquery to find the team with the most wins from each league in 2016.

-- If you need a hint, you can structure your query as follows:

-- SELECT DISTINCT lgid, ( <Write a correlated subquery here that will pull the teamid for the team with the highest number of wins from each league> )
-- FROM teams t
-- WHERE yearid = 2016;

SELECT DISTINCT lgid, 
    (SELECT teamid FROM teams t2 
     WHERE t.lgid = t2.lgid AND t2.yearid = 2016 
     ORDER BY t2.w DESC LIMIT 1) AS highest_wins
FROM teams t
WHERE yearid = 2016;

SELECT DISTINCT lgid, 
    (SELECT name FROM teams t2 
     WHERE t.lgid = t2.lgid AND t2.yearid = 2016 
     ORDER BY t2.w DESC LIMIT 1) AS highest_wins
FROM teams t
WHERE yearid = 2016;

-- Texas Rangers in AL and Chicago Cubs in NL

-- b. One downside to using correlated subqueries is that you can only return exactly one row and one column. This means, for example that if we wanted to pull in not just the teamid but also the number of wins, we couldn't do so using just a single subquery. (Try it and see the error you get). Add another correlated subquery to your query on the previous part so that your result shows not just the teamid but also the number of wins by that team.

SELECT DISTINCT lgid, 
    (SELECT name FROM teams t2 
     WHERE t.lgid = t2.lgid AND t2.yearid = 2016 
     ORDER BY t2.w DESC LIMIT 1) AS highest_wins,
	 (SELECT w FROM teams t3 
     WHERE t.lgid = t3.lgid AND t3.yearid = 2016 AND t.w = t3.w 
     ORDER BY t3.l DESC LIMIT 1) AS wins
FROM teams t
WHERE yearid = 2016;

-- c. If you are interested in pulling in the top (or bottom) values by group, you can also use the DISTINCT ON expression (https://www.postgresql.org/docs/9.5/sql-select.html#SQL-DISTINCT). Rewrite your previous query into one which uses DISTINCT ON to return the top team by league in terms of number of wins in 2016. Your query should return the league, the teamid, and the number of wins.

SELECT DISTINCT ON(lgid) lgid, teamid, w
FROM teams
WHERE yearid = 2016
ORDER BY lgid, w DESC;


-- d. If we want to pull in more than one column in our correlated subquery, another way to do it is to make use of the LATERAL keyword (https://www.postgresql.org/docs/9.4/queries-table-expressions.html#QUERIES-LATERAL). This allows you to write subqueries in FROM that make reference to columns from previous FROM items. This gives us the flexibility to pull in or calculate multiple columns or multiple rows (or both). Rewrite your previous query using the LATERAL keyword so that your result shows the teamid and number of wins for the team with the most wins from each league in 2016. 

-- If you want a hint, you can structure your query as follows:

-- SELECT *
-- FROM (SELECT DISTINCT lgid 
-- 	  FROM teams
-- 	  WHERE yearid = 2016) AS leagues,
-- 	  LATERAL ( <Fill in a subquery here to retrieve the teamid and number of wins> ) as top_teams;

SELECT *
FROM (SELECT DISTINCT lgid 
      FROM teams
      WHERE yearid = 2016) AS leagues,
      LATERAL (
       SELECT teamid, w
       FROM teams t2
       WHERE t2.lgid = leagues.lgid AND t2.yearid = 2016
       ORDER BY w DESC
       LIMIT 1
      ) AS top_teams;
	  
-- e. Finally, another advantage of the LATERAL keyword over using correlated subqueries is that you return multiple result rows. (Try to return more than one row in your correlated subquery from above and see what type of error you get). Rewrite your query on the previous problem sot that it returns the top 3 teams from each league in term of number of wins. Show the teamid and number of wins.

SELECT *
FROM (SELECT DISTINCT lgid 
      FROM teams
      WHERE yearid = 2016) AS leagues,
      LATERAL (
       SELECT teamid, w
       FROM teams t2
       WHERE t2.lgid = leagues.lgid AND t2.yearid = 2016
       ORDER BY w DESC
       LIMIT 3
      ) AS top_teams;

-- AL - TEX, CLE, BOS
-- NL - CHN, WAS, LAN

-- 2. Another advantage of lateral joins is for when you create calculated columns. In a regular query, when you create a calculated column, you cannot refer it it when you create other calculated columns. This is particularly useful if you want to reuse a calculated column multiple times. For example,

-- SELECT 
-- 	teamid,
-- 	w,
-- 	l,
-- 	w + l AS total_games,
-- 	w*100.0 / total_games AS winning_pct
-- FROM teams
-- WHERE yearid = 2016
-- ORDER BY winning_pct DESC;

-- results in the error that "total_games" does not exist. However, I can restructure this query using the LATERAL keyword.

-- SELECT
-- 	teamid,
-- 	w,
-- 	l,
-- 	total_games,
-- 	w*100.0 / total_games AS winning_pct
-- FROM teams t,
-- LATERAL (
-- 	SELECT w + l AS total_games
-- ) AS tg
-- WHERE yearid = 2016
-- ORDER BY winning_pct DESC;

-- a. Write a query which, for each player in the player table, assembles their birthyear, birthmonth, and birthday into a single column called birthdate which is of the date type.

SELECT namefirst,
       namelast,
       (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate
FROM people;

-- b. Use your previous result inside a subquery using LATERAL to calculate for each player their age at debut and age at retirement. (Hint: It might be useful to check out the PostgreSQL date and time functions https://www.postgresql.org/docs/8.4/functions-datetime.html).

SELECT namefirst,
       namelast,
       (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate,
EXTRACT(YEAR FROM age(debut::date, (birthyear || '-' || birthmonth || '-' || birthday)::date)) AS debut_age,
EXTRACT(YEAR FROM age(finalgame::date, (birthyear || '-' || birthmonth || '-' || birthday)::date)) AS retirement_age
FROM people
ORDER BY birthdate;

-- c. Who is the youngest player to ever play in the major leagues?

SELECT namefirst,
       namelast,
       (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate,
EXTRACT(YEAR FROM age(debut::date, (birthyear || '-' || birthmonth || '-' || birthday)::date)) AS debut_age,
EXTRACT(YEAR FROM age(finalgame::date, (birthyear || '-' || birthmonth || '-' || birthday)::date)) AS retirement_age
FROM people
ORDER BY debut_age
LIMIT 1;

-- Joe Nuxhall at age 15

-- d. Who is the oldest player to player in the major leagues? You'll likely have a lot of null values resulting in your age at retirement calculation. Check out the documentation on sorting rows here https://www.postgresql.org/docs/8.3/queries-order.html about how you can change how null values are sorted.

SELECT namefirst,
       namelast,
       (birthyear || '-' || birthmonth || '-' || birthday)::date AS birthdate,
EXTRACT(YEAR FROM age(debut::date, (birthyear || '-' || birthmonth || '-' || birthday)::date)) AS debut_age,
EXTRACT(YEAR FROM age(finalgame::date, (birthyear || '-' || birthmonth || '-' || birthday)::date)) AS retirement_age
FROM people
ORDER BY retirement_age DESC NULLS LAST
LIMIT 1;

-- Satchel Paige at 59 years old.

-- 3. For this question, you will want to make use of RECURSIVE CTEs (see https://www.postgresql.org/docs/13/queries-with.html). The RECURSIVE keyword allows a CTE to refer to its own output. Recursive CTEs are useful for navigating network datasets such as social networks, logistics networks, or employee hierarchies (who manages who and who manages that person). To see an example of the last item, see this tutorial: https://www.postgresqltutorial.com/postgresql-recursive-query/. 
-- In the next couple of weeks, you'll see how the graph database Neo4j can easily work with such datasets, but for now we'll see how the RECURSIVE keyword can pull it off (in a much less efficient manner) in PostgreSQL. (Hint: You might find it useful to look at this blog post when attempting to answer the following questions: https://data36.com/kevin-bacon-game-recursive-sql/.)

-- a. Willie Mays holds the record of the most All Star Game starts with 18. How many players started in an All Star Game with Willie Mays? (A player started an All Star Game if they appear in the allstarfull table with a non-null startingpos value).

SELECT COUNT(DISTINCT playerid) AS total_starters
FROM allstarfull 
WHERE gameid IN (
    SELECT gameid
    FROM allstarfull 
    WHERE playerid = 'mayswi01'
)
AND startingpos IS NOT NULL;

-- 165 players

-- b. How many players didn't start in an All Star Game with Willie Mays but started an All Star Game with another player who started an All Star Game with Willie Mays? For example, Graig Nettles never started an All Star Game with Willie Mayes, but he did star the 1975 All Star Game with Blue Vida who started the 1971 All Star Game with Willie Mays.

-- c. We'll call two players connected if they both started in the same All Star Game. Using this, we can find chains of players. For example, one chain from Carlton Fisk to Willie Mays is as follows: Carlton Fisk started in the 1973 All Star Game with Rod Carew who started in the 1972 All Star Game with Willie Mays. Find a chain of All Star starters connecting Babe Ruth to Willie Mays. 

-- d. How large a chain do you need to connect Derek Jeter to Willie Mays?