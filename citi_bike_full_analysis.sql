-- ==============================================================================
-- PROJECT: NYC Citi Bike Data Analysis
-- DESCRIPTION: End-to-end SQL analysis exploring rider demographics, 
--              station popularity, and trip durations.
-- SKILLS: Data Cleaning, Joins, Aggregations, CTEs, Window Functions
-- ==============================================================================


-- ==========================================
-- PART 1: DATA EXPLORATION
-- ==========================================

-- 1. Inspect the users table
SELECT *
FROM users
LIMIT 10;

-- 2. Find casual riders and their trip details
SELECT 
    u.user_name, 
    t.ride_id, 
    t.started_at, 
    t.ended_at, 
    t.member_casual
FROM trips t
JOIN users u ON t.user_id = u.user_id
WHERE member_casual = 'casual';

-- 3. Identify distinct genders and find users who prefer not to say
SELECT DISTINCT gender
FROM users;

SELECT 
    user_id, 
    user_name, 
    gender
FROM users
WHERE gender = 'Prefer not to say';

-- 4. Find users born in the 1990s
SELECT 
    user_id, 
    user_name, 
    date_of_birth
FROM users
WHERE date_of_birth BETWEEN '1990-01-01' AND '1999-12-31';

-- 5. Find users whose first name is Sam
SELECT 
    user_id, 
    user_name
FROM users
WHERE user_name LIKE 'Sam %';


-- ==========================================
-- PART 2: DATA CLEANING
-- ==========================================

-- 6. Clean station names by removing trailing/leading spaces
SELECT 
    station_name, 
    TRIM(station_name) AS clean_station_name
FROM stations
LIMIT 10;

-- 7. Handle missing end stations (Flags potentially lost/stolen bikes)
SELECT 
    ride_id, 
    start_station_id, 
    COALESCE(CAST(end_station_id AS VARCHAR), 'Bike Lost/Not Docked') AS end_station_status
FROM trips;

-- Bonus: Count total number of missing bikes
SELECT COUNT(*) AS lost_bikes_count
FROM trips t 
WHERE t.end_station_id IS NULL;

-- 8. Categorize rides by duration (Short, Medium, Long)
SELECT 
    ride_id, 
    started_at, 
    ended_at,
    CASE 
        WHEN EXTRACT(EPOCH FROM (CAST(ended_at AS TIMESTAMP) - CAST(started_at AS TIMESTAMP)))/60 < 10 THEN 'Short Ride'
        WHEN EXTRACT(EPOCH FROM (CAST(ended_at AS TIMESTAMP) - CAST(started_at AS TIMESTAMP)))/60 BETWEEN 10 AND 30 THEN 'Medium Ride'
        ELSE 'Long Ride' 
    END AS ride_category
FROM trips;


-- ==========================================
-- PART 3: RELATIONSHIPS (JOINS)
-- ==========================================

-- 9. Connect trips to user demographics (Inner Join)
SELECT 
    t.ride_id, 
    u.user_name, 
    u.gender, 
    t.started_at
FROM trips t 
JOIN users u ON u.user_id = t.user_id;

-- 10. Connect trips to starting stations (Left Join)
SELECT 
    t.ride_id,
    t.started_at,
    s.station_name AS start_location
FROM trips t
LEFT JOIN stations s ON t.start_station_id = s."ID";

-- 11. Multi-Table Join: The full journey of a ride
SELECT 
    u.user_name,
    ss.station_name AS starting_point,
    es.station_name AS ending_point
FROM trips t 
JOIN users u ON CAST(t.user_id AS INTEGER) = CAST(u.user_id AS INTEGER) 
LEFT JOIN stations ss ON t.start_station_id = ss."ID"
LEFT JOIN stations es ON t.end_station_id = es."ID" 
LIMIT 20;


-- ==========================================
-- PART 4: AGGREGATIONS (GROUP BY)
-- ==========================================

-- 12. Count total users by gender
SELECT 	
    gender,
    COUNT(user_id) AS total_user
FROM users
GROUP BY gender
ORDER BY total_user DESC;

-- 13. Identify the most popular starting stations
SELECT 
    s.station_name,
    COUNT(t.ride_id) AS total_starts
FROM stations s 
JOIN trips t ON s."ID" = t.start_station_id
GROUP BY s.station_name
ORDER BY total_starts DESC
LIMIT 10;

-- 14. Calculate the average ride duration per bike type
SELECT 
    rideable_type,
    AVG(EXTRACT(EPOCH FROM (CAST(ended_at AS TIMESTAMP) - CAST (started_at AS TIMESTAMP)))/60) AS average_duration_in_minutes
FROM trips
GROUP BY rideable_type;


-- ==========================================
-- PART 5: ADVANCED SQL (CTEs & WINDOWS)
-- ==========================================

-- 15. Calculate user age and filter for seniors
SELECT
    user_id,
    user_name,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, CAST(date_of_birth AS DATE))) AS age
FROM users
WHERE EXTRACT(YEAR FROM AGE(CURRENT_DATE, CAST(date_of_birth AS DATE))) > 60;

-- 16. CTE & Optimization: Count total rides taken by senior users
WITH RidersAge AS (
    SELECT 
        user_id,
        user_name,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, CAST(date_of_birth AS DATE))) AS age
    FROM users
    WHERE EXTRACT(YEAR FROM AGE(CURRENT_DATE, CAST(date_of_birth AS DATE))) > 60
)
SELECT 
    r.user_name,
    COUNT(t.ride_id) AS total_rides
FROM trips t
JOIN RidersAge r ON t.user_id = r.user_id
GROUP BY r.user_name
ORDER BY total_rides DESC;

-- 17. Window Function: Find the start time of the previous ride
SELECT 
    user_id,
    ride_id,
    started_at,
    LAG(started_at) OVER(PARTITION BY user_id ORDER BY started_at) AS previous_ride_time
FROM trips 
ORDER BY user_id, started_at
LIMIT 10;

-- 18. Window Function & CTE: Calculate minutes elapsed since last ride
WITH PreviousRide AS (
    SELECT 
        user_id,
        ride_id,
        started_at,
        LAG(started_at) OVER(PARTITION BY user_id ORDER BY started_at) AS previous_ride_start_time
    FROM trips
)
SELECT
    user_id,
    ride_id,
    previous_ride_start_time,
    ROUND(EXTRACT(EPOCH FROM (CAST(started_at AS TIMESTAMP) - CAST(previous_ride_start_time AS TIMESTAMP)))/60, 2) AS minute_since_last_ride
FROM PreviousRide
WHERE previous_ride_start_time IS NOT NULL
ORDER BY user_id, started_at
LIMIT 10;