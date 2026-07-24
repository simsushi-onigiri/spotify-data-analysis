# 1. the most popular artists based on the avg of popularity score (who have at at least 100 tracks)
select artists, avg(popularity) as artist_popularity
from spotify_data
group by artists
HAVING COUNT(*) >= 100
ORDER BY artist_popularity DESC
limit 10

# count of tracks per artist
SELECT artists, COUNT(*) 
FROM spotify_data 
GROUP BY artists 
ORDER BY COUNT(*) DESC
limit 20

# 2. top 10 most popular songs ? and what is their rank in their genre?
WITH unique_tracks AS (
    SELECT *,
    ROW_NUMBER() OVER (
            PARTITION BY track_name, artists   
            ORDER BY popularity DESC          
        ) AS row_num
    FROM spotify_data
)
SELECT
    track_name, artists, track_genre, popularity,
    RANK() OVER (ORDER BY popularity DESC)                  AS overall_rank,
    RANK() OVER (PARTITION BY track_genre ORDER BY popularity DESC) AS genre_rank
FROM unique_tracks
WHERE row_num = 1          --> drops the duplicate copies
ORDER BY overall_rank
LIMIT 10

# 3. top 10 most popular genres?
select track_genre, avg(popularity) as genre_popularity,
count(*) as total_tracks
from spotify_data
group by track_genre
ORDER BY genre_popularity DESC
limit 10

# 3. a. top performing artists in those genres
WITH top_genres AS (
    SELECT track_genre, AVG(popularity) AS genre_popularity
    FROM spotify_data
    GROUP BY track_genre
    ORDER BY genre_popularity DESC
    LIMIT 10
),
artist_genre_popu AS (
    SELECT track_genre, artists, AVG(popularity) AS avg_popu
    FROM spotify_data
    WHERE track_genre IN (SELECT track_genre FROM top_genres)   -- only the genres that made Part A's cut
    GROUP BY track_genre, artists
),
ranked AS (
    SELECT track_genre, artists, avg_popu,
        ROW_NUMBER() OVER (
            PARTITION BY track_genre
            ORDER BY avg_popu DESC, artists ASC   -- tie-breaker: without this, ties would arbitrarily pick either row
        ) AS rank_in_genre,
        RANK() OVER (PARTITION BY artists ORDER BY avg_popu DESC)     AS rank_for_artist   -- is this genre the artist's BEST genre?
    FROM artist_genre_popu
)
SELECT track_genre, artists, avg_popu
FROM ranked
WHERE rank_in_genre = 1     -- top artist for the genre
  AND rank_for_artist = 1   -- this is that artist's single best genre, so they can't also "win" elsewhere
ORDER BY avg_popu DESC;

# 4. which artists have the most explicit songs? 
--(inner query / CTE): calculate the raw numbers, give them nicknames
WITH artist_counts AS (
    SELECT artists,
        COUNT(*) FILTER (WHERE explicit = TRUE) AS explicit_count,
        COUNT(*)                                 AS total_tracks
    FROM spotify_data
    GROUP BY artists
)

-- outer query: calculate the percentage of explicit songs, order by raw count
SELECT artists, explicit_count, total_tracks,
    ROUND(explicit_count * 100.0 / total_tracks, 1)              AS explicit_percentage
FROM artist_counts
ORDER BY explicit_count DESC
LIMIT 10;

# 5. Which 20 albums have the most consistently popular tracks ?
WITH unique_tracks AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY track_name, album_name
            ORDER BY popularity DESC
        ) AS row_num
    FROM spotify_data
),
album_stats AS (
    SELECT
        album_name,
        MIN(artists)            AS artists,       
        COUNT(*)                AS track_count,
        AVG(popularity)         AS avg_popularity,
        STDDEV(popularity)         AS popularity_stddev
    FROM unique_tracks
    WHERE row_num = 1
    GROUP BY album_name         
    HAVING COUNT(*) >= 5
)
SELECT *
FROM album_stats
ORDER BY avg_popularity DESC, popularity_stddev ASC
LIMIT 20;

# 6. Is song popularity affected by track duration? ( <2 mins, 2-3 mins, 3-4 mins and >4 mins)
SELECT
    CASE
        WHEN duration_ms < 120000                        THEN '<2 min'
        WHEN duration_ms BETWEEN 120000 AND 179999        THEN '2-3 min'
        WHEN duration_ms BETWEEN 180000 AND 239999        THEN '3-4 min'
        ELSE '>4 min'
    END AS duration_bucket,
    COUNT(*)              AS track_count,
    AVG(popularity)       AS avg_popularity,
    STDDEV(popularity)    AS popularity_stddev
FROM spotify_data
GROUP BY duration_bucket
ORDER BY avg_popularity DESC;   


