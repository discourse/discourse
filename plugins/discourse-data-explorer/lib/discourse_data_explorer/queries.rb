# frozen_string_literal: true

module DiscourseDataExplorer
  class Queries
    def self.default
      # WARNING: Edit the query hash carefully
      # For each query, add id, name and description here and add sql below
      # Feel free to add new queries at the bottom of the hash in numerical order
      # If any query has been run on an instance, it is then saved in the local db
      # Locally stored queries are updated from the below data only when they are run again
      # eg. If you update a query with id=-1 in this file and the query has been run on a site,
      #     you must run the query with id=-1 on the site again to update these changes in the site db

      queries = {
        "most-common-likers": {
          id: -1,
          name: "Most Common Likers",
          description: "Which users like particular other users the most?",
        },
        "most-messages": {
          id: -2,
          name: "Who has been sending the most messages in the last week?",
          description: "tracking down suspicious PM activity",
        },
        "edited-post-spam": {
          id: -3,
          name: "Last 500 posts that were edited by TL0/TL1 users",
          description: "fighting human-driven copy-paste spam",
        },
        "new-topics": {
          id: -4,
          name: "New Topics by Category",
          description:
            "Lists all new topics ordered by category and creation_date. The query accepts a ‘months_ago’ parameter. It defaults to 0 to give you the stats for the current month.",
        },
        "active-topics": {
          id: -5,
          name: "Top 100 Active Topics",
          description:
            "based on the number of replies, it accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
        },
        "top-likers": {
          id: -6,
          name: "Top 100 Likers",
          description:
            "returns the top 100 likers for a given monthly period ordered by like_count. It accepts a ‘months_ago’ parameter, defaults to 1 to give results for the last calendar month.",
        },
        "quality-users": {
          id: -7,
          name: "Top 50 Quality Users",
          description:
            "based on post score calculated using reply count, likes, incoming links, bookmarks, time spent and read count.",
        },
        "user-participation": {
          id: -8,
          name: "User Participation Statistics",
          description: "Detailed statistics for the most active users.",
        },
        "largest-uploads": {
          id: -9,
          name: "Top 50 Largest Uploads",
          description: "sorted by file size.",
        },
        "inactive-users": {
          id: -10,
          name: "Inactive Users with no posts",
          description: "analyze pre-Discourse signups.",
        },
        "active-lurkers": {
          id: -11,
          name: "Most Active Lurkers",
          description:
            "active users without posts and excessive read times, it accepts a post_read_count parameter that sets the threshold for posts read.",
        },
        "topic-user-notification-level": {
          id: -12,
          name: "List of topics a user is watching/tracking/muted",
          description:
            "The query requires a ‘notification_level’ parameter. Use 0 for muted, 1 for regular, 2 for tracked and 3 for watched topics.",
        },
        "assigned-topics-report": {
          id: -13,
          name: "List of assigned topics by user",
          description: "This report requires the assign plugin, it will find all assigned topics",
        },
        "group-members-reply-count": {
          id: -14,
          name: "Group Members Reply Count",
          description:
            "Number of replies by members of a group over a given time period. Requires 'group_name', 'start_date', and 'end_date' parameters. Dates need to be in the form 'yyyy-mm-dd'. Accepts an 'include_pms' parameter.",
        },
        "total-assigned-topics-report": {
          id: -15,
          name: "Total topics assigned per user",
          description: "Count of assigned topis per user linking to assign list",
        },
        "poll-results": {
          id: -16,
          name: "Poll results report",
          description:
            "Details of a poll result, including details about each vote and voter, useful for analyzing results in external software.",
        },
        "top-tags-per-year": {
          id: -17,
          name: "Top tags per year",
          description: "List the top tags per year.",
        },
        number_of_replies_by_category: {
          id: -18,
          name: "Number of replies by category",
          description: "List the number of replies by category.",
        },
        "poll-results-ranked-choice": {
          id: -19,
          name: "Poll results report (for Ranked Choice polls)",
          description:
            "Details of a Ranked Choice poll result, including details about each vote and voter inc. rank, useful for analyzing results in external software.",
        },
        "weekly-unique-visitors": {
          id: -20,
          name: "Weekly Unique Visitors",
          description:
            "Number of distinct users who visited the site each week. Accepts a 'weeks_ago' parameter, defaults to the last 12 weeks.",
        },
        "top-topics-by-views": {
          id: -21,
          name: "Top 100 Topics by Views",
          description:
            "The most viewed topics in a recent period, split into anonymous and logged-in views. Accepts a 'days_ago' parameter, defaults to the last 7 days.",
        },
        "top-search-terms": {
          id: -22,
          name: "Top 200 Search Terms",
          description:
            "The most popular search terms by number of distinct users searching for them, useful for spotting content gaps. Accepts a 'days_ago' parameter, defaults to the last 30 days.",
        },
        "topic-views-and-clicks": {
          id: -23,
          name: "Topic Views and Link Clicks Over Time",
          description:
            "Daily views (anonymous and logged in) and outbound link clicks for a single topic, useful for measuring how an announcement performed. Requires a 'topic_id' parameter, accepts a 'days_ago' parameter.",
        },
        "avg-first-response-time": {
          id: -24,
          name: "Average Time to First Response",
          description:
            "Average number of hours before a new topic receives its first reply from someone other than the topic author, grouped by week. Accepts a 'weeks_ago' parameter, defaults to the last 12 weeks.",
        },
        "new-topic-response-rate": {
          id: -25,
          name: "New Topic Response Rate",
          description:
            "Percentage of new public topics that receive any reply, and a staff reply, within 30 days of creation, grouped by month. Only counts topics old enough to have had a fair chance at a reply. Accepts a 'months_ago' parameter.",
        },
        "community-participation-trend": {
          id: -26,
          name: "Community Participation Trend",
          description:
            "Monthly count of distinct non-staff users replying in public topics, with average replies per replier, useful to distinguish 'fewer people participating' from 'the same people posting less'. Accepts a 'months_ago' parameter.",
        },
        "trust-level-growth": {
          id: -27,
          name: "Trust Level Growth Summary",
          description:
            "Number of users who reached each trust level in a recent period, alongside the current total population at each level. Accepts a 'days_ago' parameter, defaults to the last 28 days.",
        },
        "topics-with-no-response": {
          id: -28,
          name: "Topics With No Response",
          description:
            "Number of topics per period that never received a reply from anyone other than the topic author. Accepts 'days_ago', 'category_id', 'include_subcategories' and 'interval' (day, week, month or year) parameters.",
        },
        "top-posters": {
          id: -29,
          name: "Top Posters in a Given Timeframe",
          description:
            "Ranks users by topics created and replies posted in a date range. Requires 'start_date' and 'end_date' parameters (yyyy-mm-dd). Accepts a 'top_x' parameter, defaults to 10.",
        },
        "category-activity": {
          id: -30,
          name: "Category Activity Breakdown",
          description:
            "Topic count, post count, likes and reads per category for a date range. Requires 'start_date' and 'end_date' parameters (yyyy-mm-dd).",
        },
        "tl3-promotion-candidates": {
          id: -31,
          name: "Trust Level 3 Promotion Progress",
          description:
            "Checks every trust level 3 promotion requirement for current trust level 2 users, mirroring the logic of the built-in promotion job. Each threshold is a parameter defaulting to the matching site setting's default. Set 'show_all_results' to false to only list users currently meeting every requirement.",
        },
        "silenced-users": {
          id: -32,
          name: "Silenced Users Report",
          description:
            "Currently silenced users, when they were silenced and by whom ('system' for automatic silences). Accepts optional 'start_date', 'end_date' and 'silenced_by' parameters.",
        },
        "user-warnings": {
          id: -33,
          name: "Recent Official Warnings",
          description:
            "Official warnings issued recently, showing who was warned, who issued the warning, and the related topic. Accepts a 'days_ago' parameter, defaults to the last 28 days.",
        },
        "most-flagged-users": {
          id: -34,
          name: "Users With Most Agreed-Upon Flags",
          description:
            "Ranks users by the number of their posts that had a flag agreed with by staff, useful for finding repeat offenders.",
        },
        "subcategory-permission-drift": {
          id: -35,
          name: "Subcategory Permission Audit",
          description:
            "Finds subcategories granting a group permission that the parent category does not grant — a permission-hygiene check not surfaced by the admin UI.",
        },
        "reading-participation-histogram": {
          id: -36,
          name: "Reading Participation Histogram",
          description:
            "Buckets users by how many posts they read in a given period, from a single post up to 2048+, showing the shape of your reading base (lurkers vs power readers). Accepts 'from_days_ago' and 'duration_days' parameters.",
        },
        "flags-by-type": {
          id: -37,
          name: "Flags by Type",
          description:
            "Number of flags per flag type, split into flags reported by real users and flags raised by automated accounts (system, bots). Accepts a 'days_ago' parameter, defaults to the last 90 days.",
        },
        "flags-handled-by-staff": {
          id: -38,
          name: "Flags Handled by Staff Member",
          description:
            "Number of review queue items handled per staff member, useful for recognizing moderation workload. Accepts a 'days_ago' parameter, defaults to the last 90 days.",
        },
        "suspended-users": {
          id: -39,
          name: "Suspended Users Report",
          description:
            "Currently suspended users, when they were suspended, until when, by whom and why. Accepts optional 'start_date', 'end_date' and 'suspended_by' parameters.",
        },
        "foreign-language-topics": {
          id: -40,
          name: "Topics Not in the Site's Primary Language",
          description:
            "Recently created topics whose detected language differs from the site's primary language, useful for routing content for translation or moderation. WARNING: requires content localization with locale detection to be enabled (e.g. the content_localization_enabled and ai_translation_enabled site settings); without it topics have no locale recorded and this report will be empty. Accepts 'primary_locale' and 'days_ago' parameters.",
        },
        "foreign-language-posts": {
          id: -41,
          name: "Posts Not in the Site's Primary Language",
          description:
            "Recent posts whose detected language differs from the site's primary language, with a short excerpt. WARNING: requires content localization with locale detection to be enabled (e.g. the content_localization_enabled and ai_translation_enabled site settings); without it posts have no locale recorded and this report will be empty. Accepts 'primary_locale' and 'days_ago' parameters.",
        },
        "crawler-traffic-overview": {
          id: -42,
          name: "Crawler and Bot Traffic Overview",
          description:
            "Buckets recent pageviews by bot-likelihood score from Discourse's built-in crawler detection, from 'definitely user' to 'definitely crawler'. WARNING: requires browser pageview event collection to be enabled (hidden site setting trigger_browser_pageview_events); without it no events are recorded and this report will be empty. Accepts an 'hours' parameter, defaults to the last 24 hours.",
        },
        "crawler-traffic-detailed": {
          id: -43,
          name: "Crawler and Bot Traffic Detailed Report",
          description:
            "Row-per-IP breakdown of likely bot pageview activity, with the individual signals that drove the score (automated user agent, known crawler network, velocity, session churn, rapid navigation, bad referrer). WARNING: requires browser pageview event collection to be enabled (hidden site setting trigger_browser_pageview_events); without it no events are recorded and this report will be empty. Accepts 'hours' and 'min_score' parameters.",
        },
        "suspected-bot-networks": {
          id: -44,
          name: "Suspected Automated Traffic by IP and Network",
          description:
            "Networks (ASNs) and IPs generating high pageview volume with bot-like session patterns (near 1.0 views per session, rotating user agents, systematic topic harvesting), sorted so a scrape spread across many IPs on one network floats to the top. WARNING: requires browser pageview event collection to be enabled (hidden site setting trigger_browser_pageview_events); without it no events are recorded and this report will be empty. Accepts a 'days_ago' parameter, defaults to the last 3 days.",
        },
      }.with_indifferent_access

      queries["most-common-likers"]["sql"] = <<~SQL
      WITH pairs AS (
          SELECT p.user_id liked, pa.user_id liker
          FROM post_actions pa
          LEFT JOIN posts p ON p.id = pa.post_id
          WHERE post_action_type_id = 2
      )
      SELECT liker liker_user_id, liked liked_user_id, count(*)
      FROM pairs
      GROUP BY liked, liker
      ORDER BY count DESC
      SQL

      queries["most-messages"]["sql"] = <<~SQL
      SELECT user_id, count(*) AS message_count
      FROM topics
      WHERE archetype = 'private_message' AND subtype = 'user_to_user'
      AND age(created_at) < interval '7 days'
      GROUP BY user_id
      ORDER BY message_count DESC
      SQL

      queries["edited-post-spam"]["sql"] = <<~SQL
      SELECT
          p.id AS post_id,
          topic_id
      FROM posts p
          JOIN users u
              ON u.id = p.user_id
          JOIN topics t
              ON t.id = p.topic_id
      WHERE p.last_editor_id = p.user_id
          AND p.self_edits > 0
          AND (u.trust_level = 0 OR u.trust_level = 1)
          AND p.deleted_at IS NULL
          AND t.deleted_at IS NULL
          AND t.archetype = 'regular'
      ORDER BY p.updated_at DESC
      LIMIT 500
      SQL

      queries["new-topics"]["sql"] = <<~SQL
      -- [params]
      -- int :months_ago = 1

      WITH query_period as (
          SELECT
              date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' as period_start,
              date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' + INTERVAL '1 month' - INTERVAL '1 second' as period_end
      )

      SELECT
          t.id as topic_id,
          t.category_id
      FROM topics t
      RIGHT JOIN query_period qp
          ON t.created_at >= qp.period_start
              AND t.created_at <= qp.period_end
      WHERE t.user_id > 0
          AND t.category_id IS NOT NULL
      ORDER BY t.category_id, t.created_at DESC
      SQL

      queries["active-topics"]["sql"] = <<~SQL
      -- [params]
      -- int :months_ago = 1

      WITH query_period AS
      (SELECT date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' AS period_start,
                                                          date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' + INTERVAL '1 month' - INTERVAL '1 second' AS period_end)
      SELECT t.id AS topic_id,
          t.category_id,
          COUNT(p.id) AS reply_count
      FROM topics t
      JOIN posts p ON t.id = p.topic_id
      JOIN query_period qp ON p.created_at >= qp.period_start
      AND p.created_at <= qp.period_end
      WHERE t.archetype = 'regular'
      AND t.user_id > 0
      GROUP BY t.id
      ORDER BY COUNT(p.id) DESC, t.score DESC
      LIMIT 100
      SQL

      queries["top-likers"]["sql"] = <<~SQL
      -- [params]
      -- int :months_ago = 1

      WITH query_period AS (
          SELECT
              date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' as period_start,
              date_trunc('month', CURRENT_DATE) - INTERVAL ':months_ago months' + INTERVAL '1 month' - INTERVAL '1 second' as period_end
              )

          SELECT
              ua.user_id,
              count(1) AS like_count
          FROM user_actions ua
          INNER JOIN query_period qp
          ON ua.created_at >= qp.period_start
          AND ua.created_at <= qp.period_end
          WHERE ua.action_type = 1
          GROUP BY ua.user_id
          ORDER BY like_count DESC
          LIMIT 100
      SQL

      queries["quality-users"]["sql"] = <<~SQL
      SELECT sum(p.score) / count(p) AS "average score per post",
          count(p.id) AS post_count,
          p.user_id
      FROM posts p
      JOIN users u ON u.id = p.user_id
      WHERE p.created_at >= CURRENT_DATE - INTERVAL '6 month'
      AND NOT u.admin
      AND u.active
      GROUP BY user_id,
          u.views
      HAVING count(p.id) > 50
      ORDER BY sum(p.score) / count(p) DESC
      LIMIT 50
      SQL

      queries["user-participation"]["sql"] = <<~SQL
      -- [params]
      -- int :from_days_ago = 0
      -- int :duration_days = 30
      WITH t AS (
          SELECT CURRENT_TIMESTAMP - ((:from_days_ago + :duration_days) * (INTERVAL '1 days')) AS START,
              CURRENT_TIMESTAMP - (:from_days_ago * (INTERVAL '1 days')) AS END
      ),
      pr AS (
          SELECT user_id, COUNT(1) AS visits,
              SUM(posts_read) AS posts_read
          FROM user_visits, t
          WHERE posts_read > 0
              AND visited_at > t.START
              AND visited_at < t.
              END
          GROUP BY
              user_id
      ),
      pc AS (
          SELECT user_id, COUNT(1) AS posts_created
          FROM posts, t
          WHERE
              created_at > t.START
              AND created_at < t.
              END
          GROUP BY
              user_id
      ),
      ttopics AS (
          SELECT user_id, posts_count
          FROM topics, t
          WHERE created_at > t.START
              AND created_at < t.
              END
      ),
      tc AS (
          SELECT user_id, COUNT(1) AS topics_created
          FROM ttopics
          GROUP BY user_id
      ),
      twr AS (
          SELECT user_id, COUNT(1) AS topics_with_replies
          FROM ttopics
          WHERE posts_count > 1
          GROUP BY user_id
      ),
      tv AS (
          SELECT user_id,
              COUNT(DISTINCT(topic_id)) AS topics_viewed
          FROM topic_views, t
          WHERE viewed_at > t.START
              AND viewed_at < t.
              END
          GROUP BY user_id
      ),
      likes AS (
          SELECT post_actions.user_id AS given_by_user_id,
              posts.user_id AS received_by_user_id
          FROM t,
              post_actions
              LEFT JOIN
              posts
              ON post_actions.post_id = posts.id
          WHERE
              post_actions.created_at > t.START
              AND post_actions.created_at < t.
              END
              AND post_action_type_id = 2
      ),
      lg AS (
          SELECT given_by_user_id AS user_id,
              COUNT(1) AS likes_given
          FROM likes
          GROUP BY user_id
      ),
      lr AS (
          SELECT received_by_user_id AS user_id,
              COUNT(1) AS likes_received
          FROM likes
          GROUP BY user_id
      ),
      e AS (
          SELECT email, user_id
          FROM user_emails u
          WHERE u.PRIMARY = TRUE
      )
      SELECT
          pr.user_id,
          username,
          name,
          email,
          visits,
          COALESCE(topics_viewed, 0) AS topics_viewed,
          COALESCE(posts_read, 0) AS posts_read,
          COALESCE(posts_created, 0) AS posts_created,
          COALESCE(topics_created, 0) AS topics_created,
          COALESCE(topics_with_replies, 0) AS topics_with_replies,
          COALESCE(likes_given, 0) AS likes_given,
          COALESCE(likes_received, 0) AS likes_received
      FROM pr
      LEFT JOIN tv USING (user_id)
      LEFT JOIN pc USING (user_id)
      LEFT JOIN tc USING (user_id)
      LEFT JOIN twr USING (user_id)
      LEFT JOIN lg USING (user_id)
      LEFT JOIN lr USING (user_id)
      LEFT JOIN e USING (user_id)
      LEFT JOIN users ON pr.user_id = users.id
      ORDER BY
          visits DESC,
          posts_read DESC,
          posts_created DESC
      SQL

      queries["largest-uploads"]["sql"] = <<~SQL
      SELECT posts.id AS post_id,
          uploads.original_filename,
          ROUND(uploads.filesize / 1000000.0, 2) AS size_in_mb,
          uploads.extension,
          uploads.created_at,
          uploads.url
      FROM upload_references
      JOIN uploads ON uploads.id = upload_references.upload_id
      JOIN posts ON posts.id = upload_references.target_id AND upload_references.target_type = 'Post'
      ORDER BY uploads.filesize DESC
      LIMIT 50
      SQL

      queries["inactive-users"]["sql"] = <<~SQL
      SELECT
          u.id,
          u.username_lower AS "username",
          u.created_at,
          u.last_seen_at
      FROM users u
      WHERE u.active = false
      ORDER BY u.id
      SQL

      queries["active-lurkers"]["sql"] = <<~SQL
      -- [params]
      -- int :post_read_count = 100
      WITH posts_by_user AS (
          SELECT COUNT(*) AS posts, user_id
          FROM posts
          GROUP BY user_id
      ), posts_read_by_user AS (
          SELECT SUM(posts_read) AS posts_read, user_id
          FROM user_visits
          GROUP BY user_id
      )
      SELECT
          u.id,
          u.username_lower AS "username",
          u.created_at,
          u.last_seen_at,
          COALESCE(pbu.posts, 0) AS "posts_created",
          COALESCE(prbu.posts_read, 0) AS "posts_read"
      FROM users u
      LEFT JOIN posts_by_user pbu ON pbu.user_id = u.id
      LEFT JOIN posts_read_by_user prbu ON prbu.user_id = u.id
      WHERE u.active = true
      AND posts IS NULL
      AND posts_read > :post_read_count
      ORDER BY u.id
      SQL

      queries["topic-user-notification-level"]["sql"] = <<~SQL
      -- [params]
      -- null int :user
      -- null int :notification_level

      SELECT t.category_id AS category_id, t.id AS topic_id, tu.last_visited_at AS topic_last_visited_at
      FROM topics t
      JOIN topic_users tu ON tu.topic_id = t.id AND tu.user_id = :user AND tu.notification_level = :notification_level
      ORDER BY tu.last_visited_at DESC
      SQL

      queries["assigned-topics-report"]["sql"] = <<~SQL
        SELECT a.assigned_to_id user_id, a.topic_id
        FROM assignments a
        JOIN topics t on t.id = a.topic_id
        JOIN users u on u.id = a.assigned_to_id
          WHERE a.assigned_to_type = 'User'
          AND t.deleted_at IS NULL
        ORDER BY username, topic_id
      SQL

      queries["group-members-reply-count"]["sql"] = <<~SQL
        -- [params]
        -- date :start_date
        -- date :end_date
        -- string :group_name
        -- boolean :include_pms = false

        WITH target_users AS (
        SELECT
        u.id AS user_id
        FROM users u
        JOIN group_users gu
        ON gu.user_id = u.id
        JOIN groups g
        ON g.id = gu.group_id
        WHERE g.name = :group_name
        AND gu.created_at::date <= :end_date
        ),
        target_posts AS (
        SELECT
        p.id,
        p.user_id
        FROM posts p
        JOIN topics t
        ON t.id = p.topic_id
        WHERE CASE WHEN :include_pms THEN true ELSE t.archetype = 'regular' END
        AND t.deleted_at IS NULL
        AND p.deleted_at IS NULL
        AND p.created_at::date >= :start_date
        AND p.created_at::date <= :end_date
        AND p.post_number > 1
        )

        SELECT
        tu.user_id,
        COALESCE(COUNT(tp.id), 0) AS reply_count
        FROM target_users tu
        LEFT OUTER JOIN target_posts tp
        ON tp.user_id = tu.user_id
        GROUP BY tu.user_id
        ORDER BY reply_count DESC, tu.user_id
      SQL

      queries["total-assigned-topics-report"]["sql"] = <<~SQL
        SELECT a.assigned_to_id AS user_id,
        count(*)::varchar || ',/u/' || username_lower || '/activity/assigned' assigned_url
        FROM assignments a
        JOIN topics t on t.id = a.topic_id
        JOIN users u on u.id = a.assigned_to_id
        WHERE a.assigned_to_type = 'User'
          AND t.deleted_at IS NULL
        GROUP BY a.assigned_to_id, username_lower
        ORDER BY count(*) DESC, username_lower
      SQL

      queries["poll-results"]["sql"] = <<~SQL
        -- [params]
        -- string :poll_name
        -- int :post_id

        SELECT
          poll_votes.updated_at AS vote_time,
          poll_votes.poll_option_id AS vote_option,
          users.id AS user_id,
          users.username,
          users.name,
          users.trust_level,
          poll_options.html AS vote_option_full
        FROM
          poll_votes
        INNER JOIN
          polls ON polls.id = poll_votes.poll_id
        INNER JOIN
          users ON users.id = poll_votes.user_id
        INNER JOIN
          poll_options ON poll_votes.poll_id = poll_options.poll_id AND poll_votes.poll_option_id = poll_options.id
        WHERE
          polls.name = :poll_name AND
          polls.post_id = :post_id
      SQL

      queries["poll-results-ranked-choice"]["sql"] = <<~SQL
      -- [params]
      -- string :poll_name
      -- int :post_id

        SELECT
          poll_votes.updated_at AS vote_time,
          poll_votes.poll_option_id AS vote_option,
          poll_votes.rank AS vote_rank,
          users.id AS user_id,
          users.username,
          users.name,
          users.trust_level,
          poll_options.html AS vote_option_full
        FROM
          poll_votes
        INNER JOIN
          polls ON polls.id = poll_votes.poll_id
        INNER JOIN
          users ON users.id = poll_votes.user_id
        INNER JOIN
          poll_options ON poll_votes.poll_id = poll_options.poll_id AND poll_votes.poll_option_id = poll_options.id
        WHERE
          polls.name = :poll_name AND
          polls.post_id = :post_id
      SQL

      queries["top-tags-per-year"]["sql"] = <<~SQL
    -- [params]
    -- integer :rank_max = 5

    WITH data AS (SELECT
        tag_id,
        EXTRACT(YEAR FROM created_at) AS year
    FROM topic_tags)

    SELECT year, rank, name, qt FROM (
        SELECT
      tag_id,
      COUNT(tag_id) AS qt,
      year,
      rank() OVER (PARTITION BY year ORDER BY COUNT(tag_id) DESC) AS rank
        FROM
      data
        GROUP BY year, tag_id) as rnk
    INNER JOIN tags ON tags.id = rnk.tag_id
    WHERE rank <= :rank_max
    ORDER BY year DESC, qt DESC
      SQL

      queries["number_of_replies_by_category"]["sql"] = <<~SQL
    -- [params]
    -- boolean :enable_null_category = false

    WITH post AS (SELECT
        id AS post_id,
        topic_id,
        EXTRACT(YEAR FROM created_at) AS year
    FROM posts
    WHERE post_type = 1
        AND deleted_at ISNULL
        AND post_number != 1)

    SELECT
        p.year,
        t.category_id AS id,
        c.name category,
        COUNT(p.post_id) AS qt
    FROM post p
    INNER JOIN topics t ON t.id = p.topic_id
    LEFT JOIN categories c ON c.id = t.category_id
    WHERE t.deleted_at ISNULL
        AND (:enable_null_category = true OR t.category_id NOTNULL)
    GROUP BY t.category_id, c.name, p.year
    ORDER BY p.year DESC, qt DESC
      SQL

      queries["weekly-unique-visitors"]["sql"] = <<~SQL
      -- [params]
      -- int :weeks_ago = 12

      SELECT
          DATE_TRUNC('week', visited_at)::date AS week,
          COUNT(DISTINCT user_id) AS active_users
      FROM user_visits
      WHERE visited_at >= CURRENT_DATE - (:weeks_ago * INTERVAL '1 week')
      GROUP BY week
      ORDER BY week
      SQL

      queries["top-topics-by-views"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 7

      SELECT
          t.id AS topic_id,
          t.category_id,
          COALESCE(SUM(tvs.anonymous_views), 0) AS anonymous_views,
          COALESCE(SUM(tvs.logged_in_views), 0) AS logged_in_views,
          COALESCE(SUM(tvs.anonymous_views + tvs.logged_in_views), 0) AS total_views
      FROM topics t
      JOIN topic_view_stats tvs ON tvs.topic_id = t.id
          AND tvs.viewed_at >= CURRENT_DATE - :days_ago
      WHERE t.deleted_at IS NULL
          AND t.archetype = 'regular'
      GROUP BY t.id, t.category_id
      ORDER BY total_views DESC
      LIMIT 100
      SQL

      queries["top-search-terms"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 30

      SELECT
          term,
          COUNT(*) AS searches,
          COUNT(DISTINCT user_id) AS distinct_users
      FROM search_logs
      WHERE created_at >= CURRENT_DATE - :days_ago
      GROUP BY term
      ORDER BY distinct_users DESC, searches DESC
      LIMIT 200
      SQL

      queries["topic-views-and-clicks"]["sql"] = <<~SQL
      -- [params]
      -- topic_id :topic_id
      -- int :days_ago = 30

      -- gapless day series, so days with zero activity still show up as rows
      WITH day_series AS (
          SELECT generate_series(
              CURRENT_DATE - :days_ago,
              CURRENT_DATE,
              '1 day'::interval
          )::date AS day
      ),
      daily_clicks AS (
          SELECT
              tlc.created_at::date AS day,
              COUNT(*) AS link_clicks
          FROM topic_link_clicks tlc
          JOIN topic_links tl ON tl.id = tlc.topic_link_id
          WHERE tl.topic_id = :topic_id
              AND tlc.created_at >= CURRENT_DATE - :days_ago
          GROUP BY tlc.created_at::date
      ),
      daily_views AS (
          SELECT
              viewed_at AS day,
              COALESCE(SUM(anonymous_views), 0) AS anonymous_views,
              COALESCE(SUM(logged_in_views), 0) AS logged_in_views
          FROM topic_view_stats
          WHERE topic_id = :topic_id
              AND viewed_at >= CURRENT_DATE - :days_ago
          GROUP BY viewed_at
      )
      SELECT
          ds.day,
          COALESCE(dv.anonymous_views, 0) + COALESCE(dv.logged_in_views, 0) AS total_views,
          COALESCE(dv.anonymous_views, 0) AS anonymous_views,
          COALESCE(dv.logged_in_views, 0) AS logged_in_views,
          COALESCE(dc.link_clicks, 0) AS link_clicks
      FROM day_series ds
      LEFT JOIN daily_views dv ON dv.day = ds.day
      LEFT JOIN daily_clicks dc ON dc.day = ds.day
      ORDER BY ds.day
      SQL

      queries["avg-first-response-time"]["sql"] = <<~SQL
      -- [params]
      -- int :weeks_ago = 12

      SELECT
          week,
          ROUND(AVG(hours_to_response)::numeric, 1) AS avg_hours_to_first_response
      FROM (
          SELECT
              DATE_TRUNC('week', t.created_at)::date AS week,
              EXTRACT(EPOCH FROM MIN(p.created_at) - t.created_at) / 3600.0 AS hours_to_response
          FROM topics t
          JOIN posts p ON p.topic_id = t.id
          WHERE t.created_at >= CURRENT_DATE - (:weeks_ago * INTERVAL '1 week')
              AND t.archetype = 'regular'
              AND t.deleted_at IS NULL
              AND p.deleted_at IS NULL
              AND p.post_number > 1
              AND p.user_id <> t.user_id
              AND p.post_type = 1
          GROUP BY t.id, week
      ) per_topic
      GROUP BY week
      ORDER BY week
      SQL

      queries["new-topic-response-rate"]["sql"] = <<~SQL
      -- [params]
      -- int :months_ago = 6

      WITH base_topics AS (
          SELECT
              t.id,
              t.created_at,
              date_trunc('month', t.created_at)::date AS month
          FROM topics t
          LEFT JOIN categories c ON c.id = t.category_id
          WHERE t.created_at >= date_trunc('month', CURRENT_DATE) - (:months_ago * INTERVAL '1 month')
              -- only count topics old enough to have had the full 30-day reply window
              AND t.created_at < CURRENT_DATE - INTERVAL '30 days'
              AND t.deleted_at IS NULL
              AND t.archetype = 'regular'
              AND COALESCE(c.read_restricted, false) = false
              AND t.user_id > 0
      ),
      topic_responses AS (
          SELECT
              bt.month,
              EXISTS (
                  SELECT 1
                  FROM posts p
                  WHERE p.topic_id = bt.id
                      AND p.post_number > 1
                      AND p.post_type = 1
                      AND p.deleted_at IS NULL
                      AND p.created_at <= bt.created_at + INTERVAL '30 days'
              ) AS has_any_reply,
              EXISTS (
                  SELECT 1
                  FROM posts p
                  JOIN users u ON u.id = p.user_id
                  WHERE p.topic_id = bt.id
                      AND p.post_number > 1
                      AND p.post_type = 1
                      AND p.deleted_at IS NULL
                      AND p.created_at <= bt.created_at + INTERVAL '30 days'
                      AND (u.admin OR u.moderator)
              ) AS has_staff_reply
          FROM base_topics bt
      )
      SELECT
          month,
          ROUND(100.0 * COUNT(*) FILTER (WHERE has_any_reply) / COUNT(*), 1) AS any_reply_pct,
          ROUND(100.0 * COUNT(*) FILTER (WHERE has_staff_reply) / COUNT(*), 1) AS staff_reply_pct
      FROM topic_responses
      GROUP BY month
      ORDER BY month
      SQL

      queries["community-participation-trend"]["sql"] = <<~SQL
      -- [params]
      -- int :months_ago = 6

      WITH monthly AS (
          SELECT
              date_trunc('month', p.created_at)::date AS month,
              COUNT(*) AS replies,
              COUNT(DISTINCT p.user_id) AS distinct_repliers
          FROM posts p
          JOIN topics t ON t.id = p.topic_id
          JOIN users u ON u.id = p.user_id
          LEFT JOIN categories c ON c.id = t.category_id
          WHERE p.created_at >= date_trunc('month', CURRENT_DATE) - (:months_ago * INTERVAL '1 month')
              AND p.deleted_at IS NULL
              AND p.post_type = 1
              AND p.post_number > 1
              AND t.deleted_at IS NULL
              AND t.archetype = 'regular'
              AND COALESCE(c.read_restricted, false) = false
              AND u.id > 0
              AND NOT u.admin
              AND NOT u.moderator
          GROUP BY 1
      )
      SELECT
          month,
          distinct_repliers,
          ROUND(replies::numeric / NULLIF(distinct_repliers, 0), 2) AS replies_per_person
      FROM monthly
      ORDER BY month
      SQL

      queries["trust-level-growth"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 28

      -- new signups with no recorded trust level change are still at trust level 0
      WITH trust_level_0_users AS (
          SELECT
              0 AS trust_level,
              COUNT(*) AS users_gained
          FROM users u
          LEFT JOIN (
              SELECT DISTINCT target_user_id
              FROM user_histories
              WHERE created_at >= CURRENT_DATE - :days_ago
                  AND action IN (2, 15) -- change_trust_level, auto_trust_level_change
          ) tlc ON u.id = tlc.target_user_id
          WHERE u.created_at >= CURRENT_DATE - :days_ago
              AND tlc.target_user_id IS NULL
      ),
      trust_level_changes AS (
          SELECT
              uh.new_value::int AS trust_level,
              COUNT(DISTINCT uh.target_user_id) AS users_gained
          FROM user_histories uh
          JOIN users u ON uh.target_user_id = u.id
          WHERE uh.created_at >= CURRENT_DATE - :days_ago
              AND uh.action IN (2, 15) -- change_trust_level, auto_trust_level_change
              AND uh.new_value IN ('1', '2', '3', '4')
          GROUP BY uh.new_value
      ),
      trust_levels_combined AS (
          SELECT generate_series(0, 4) AS trust_level
      )
      SELECT
          t.trust_level,
          CASE
              WHEN t.trust_level = 0 THEN COALESCE(tl0.users_gained, 0)
              ELSE COALESCE(tlc.users_gained, 0)
          END AS users_gained_recently,
          (SELECT COUNT(*) FROM users WHERE trust_level = t.trust_level) AS total_users_at_level
      FROM trust_levels_combined t
      LEFT JOIN trust_level_changes tlc ON t.trust_level = tlc.trust_level
      LEFT JOIN trust_level_0_users tl0 ON t.trust_level = 0
      ORDER BY t.trust_level
      SQL

      queries["topics-with-no-response"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 90
      -- null category_id :category_id
      -- boolean :include_subcategories = false
      -- string :interval = day

      WITH no_response_topics AS (
          SELECT * FROM (
              SELECT t.id, t.created_at, MIN(p.post_number) AS first_reply
              FROM topics t
              -- reply conditions live in the join, so topics with no replies
              -- survive with first_reply NULL instead of being filtered out
              LEFT JOIN posts p ON p.topic_id = t.id
                  AND p.user_id <> t.user_id
                  AND p.deleted_at IS NULL
                  AND p.post_type = 1
              WHERE t.archetype = 'regular'
                  AND t.deleted_at IS NULL
                  AND t.created_at >= CURRENT_DATE - :days_ago
                  AND (
                      :category_id IS NULL
                      OR t.category_id = :category_id
                      OR (:include_subcategories AND t.category_id IN (
                          SELECT id FROM categories WHERE parent_category_id = :category_id
                      ))
                  )
              GROUP BY t.id
          ) tt
          WHERE tt.first_reply IS NULL OR tt.first_reply < 2
      )
      SELECT
          date_trunc(:interval, created_at)::date AS period,
          COUNT(id) AS topics_without_response
      FROM no_response_topics
      GROUP BY period
      ORDER BY period
      SQL

      queries["top-posters"]["sql"] = <<~SQL
      -- [params]
      -- date :start_date
      -- date :end_date
      -- int :top_x = 10

      SELECT
          p.user_id,
          COUNT(*) AS topics_plus_replies,
          COUNT(*) FILTER (WHERE p.post_number = 1) AS topics,
          COUNT(*) FILTER (WHERE p.post_number <> 1) AS replies
      FROM posts p
      JOIN topics t ON t.id = p.topic_id
      WHERE p.created_at::date BETWEEN :start_date AND :end_date
          AND t.archetype = 'regular'
          AND p.deleted_at IS NULL
          AND t.deleted_at IS NULL
          AND p.post_type = 1
          AND p.user_id > 0
      GROUP BY p.user_id
      ORDER BY topics_plus_replies DESC
      LIMIT :top_x
      SQL

      queries["category-activity"]["sql"] = <<~SQL
      -- [params]
      -- date :start_date
      -- date :end_date

      SELECT
          c.id AS category_id,
          COUNT(DISTINCT t.id) AS topics,
          COUNT(p.id) AS posts,
          SUM(p.like_count) AS likes,
          SUM(p.reads) AS reads
      FROM categories c
      JOIN topics t ON t.category_id = c.id
      JOIN posts p ON p.topic_id = t.id AND p.post_type = 1
      WHERE p.created_at::date BETWEEN :start_date AND :end_date
          AND p.deleted_at IS NULL
          AND t.deleted_at IS NULL
      GROUP BY c.id
      ORDER BY COUNT(p.id) DESC
      SQL

      queries["tl3-promotion-candidates"]["sql"] = <<~SQL
      -- [params]
      -- int :tl_time_period = 100
      -- int :tl_requires_days_visited = 50
      -- int :tl_requires_topics_replied_to = 10
      -- int :tl_requires_topics_viewed = 25
      -- int :tl_requires_topics_viewed_cap = 500
      -- int :tl_requires_posts_read = 25
      -- int :tl_requires_posts_read_cap = 20000
      -- int :tl_requires_max_flagged = 5
      -- int :tl_requires_topics_viewed_all_time = 200
      -- int :tl_requires_posts_read_all_time = 500
      -- int :tl_requires_likes_given = 30
      -- int :tl_requires_likes_received = 20
      -- boolean :show_all_results = true

      WITH tl3_candidates AS (
          SELECT id AS user_id FROM users
          WHERE trust_level = 2
          AND last_seen_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
      ),
      min_topics_viewed AS (
          SELECT LEAST(COUNT(*) * (:tl_requires_topics_viewed / 100.0), :tl_requires_topics_viewed_cap) AS min_topics_viewed
          FROM topics
          WHERE visible = true AND archetype = 'regular'
              AND created_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
      ),
      min_posts_read AS (
          SELECT LEAST(COUNT(*) * (:tl_requires_posts_read / 100.0), :tl_requires_posts_read_cap) AS min_posts_read
          FROM posts p
          JOIN topics t ON t.id = p.topic_id
          WHERE t.deleted_at IS NULL AND t.archetype = 'regular'
              AND p.deleted_at IS NULL AND p.post_type = 1
              AND p.created_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
      ),
      min_likes_received_days AS (
          SELECT LEAST(:tl_requires_likes_received::float / 3.0, 0.75 * :tl_time_period::float)
      ),
      days_visited AS (
          SELECT uv.user_id, COUNT(uv.user_id) AS days_visited
          FROM user_visits uv
          JOIN tl3_candidates c ON c.user_id = uv.user_id
          WHERE visited_at > CURRENT_DATE - (:tl_time_period || ' days')::interval AND posts_read >= 0
          GROUP BY uv.user_id
      ),
      num_topics_replied_to AS (
          SELECT p.user_id, COUNT(DISTINCT p.topic_id) AS topic_reply_count
          FROM posts p
          JOIN topics t ON t.id = p.topic_id
          JOIN tl3_candidates c ON c.user_id = p.user_id
          WHERE p.user_id <> t.user_id AND t.archetype <> 'private_message'
              AND p.deleted_at IS NULL AND t.deleted_at IS NULL
              AND p.created_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
          GROUP BY p.user_id
      ),
      topics_viewed AS (
          SELECT tv.user_id, COUNT(tv.user_id) AS topic_view_count
          FROM topic_views tv
          JOIN topics t ON t.id = tv.topic_id
          JOIN tl3_candidates c ON c.user_id = tv.user_id
          WHERE t.archetype <> 'private_message'
              AND viewed_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
          GROUP BY tv.user_id
      ),
      posts_read AS (
          SELECT uv.user_id, SUM(posts_read) AS posts_read
          FROM user_visits uv
          JOIN tl3_candidates c ON c.user_id = uv.user_id
          WHERE visited_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
          GROUP BY uv.user_id
      ),
      num_flagged_posts AS (
          SELECT p.user_id, COUNT(DISTINCT pa.post_id) AS num_flagged_posts
          FROM post_actions pa
          JOIN posts p ON p.id = pa.post_id
          JOIN tl3_candidates c ON c.user_id = p.user_id
          WHERE p.created_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
              AND (spam_count > 0 OR inappropriate_count > 0)
              AND agreed_at IS NOT NULL AND pa.user_id <> p.user_id
          GROUP BY p.user_id
      ),
      num_flagged_by_users AS (
          SELECT p.user_id, COUNT(DISTINCT pa.user_id) AS num_flagged_by_users
          FROM post_actions pa
          JOIN posts p ON p.id = pa.post_id
          JOIN tl3_candidates c ON c.user_id = p.user_id
          WHERE p.created_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
              AND (spam_count > 0 OR inappropriate_count > 0)
              AND agreed_at IS NOT NULL AND pa.user_id <> p.user_id
          GROUP BY p.user_id
      ),
      topics_viewed_all_time AS (
          SELECT tv.user_id, COUNT(topic_id) AS topics_viewed_all_time
          FROM topic_views tv
          JOIN topics t ON t.id = tv.topic_id
          JOIN tl3_candidates c ON c.user_id = tv.user_id
          WHERE t.archetype = 'regular'
          GROUP BY tv.user_id
      ),
      posts_read_all_time AS (
          SELECT uv.user_id, SUM(posts_read) AS posts_read_all_time
          FROM user_visits uv
          JOIN tl3_candidates c ON c.user_id = uv.user_id
          GROUP BY uv.user_id
      ),
      num_likes_given AS (
          SELECT ua.user_id, COUNT(*) AS num_likes_given
          FROM user_actions ua
          JOIN topics t ON t.id = ua.target_topic_id
          JOIN tl3_candidates c ON c.user_id = ua.user_id
          WHERE ua.created_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
              AND t.archetype = 'regular' AND ua.action_type = 1
          GROUP BY ua.user_id
      ),
      num_likes_received AS (
          SELECT ua.user_id, COUNT(*) AS num_likes_received,
              COUNT(DISTINCT acting_user_id) AS num_likes_received_users,
              COUNT(DISTINCT ua.created_at::date) AS num_likes_received_days
          FROM user_actions ua
          JOIN topics t ON t.id = ua.target_topic_id
          JOIN tl3_candidates c ON c.user_id = ua.user_id
          WHERE ua.created_at >= CURRENT_DATE - (:tl_time_period || ' days')::interval
              AND t.archetype = 'regular' AND ua.action_type = 2
          GROUP BY ua.user_id
      ),
      candidate_results AS (
          SELECT
              c.user_id,
              COALESCE(days_visited, 0) AS days_visited,
              COALESCE(days_visited, 0) >= :tl_requires_days_visited AS visits_criteria_met,
              COALESCE(topic_reply_count, 0) AS topic_reply_count,
              COALESCE(topic_reply_count, 0) >= :tl_requires_topics_replied_to AS replies_criteria_met,
              COALESCE(topic_view_count, 0) AS topic_view_count,
              COALESCE(topic_view_count, 0) >= (SELECT * FROM min_topics_viewed) AS topic_views_criteria_met,
              COALESCE(posts_read, 0) AS posts_read,
              COALESCE(posts_read, 0) >= (SELECT * FROM min_posts_read) AS posts_read_criteria_met,
              COALESCE(num_flagged_posts, 0) AS num_flagged_posts,
              COALESCE(num_flagged_posts, 0) <= :tl_requires_max_flagged AS flagged_post_criteria_met,
              COALESCE(num_flagged_by_users, 0) AS num_flagged_by_users,
              COALESCE(num_flagged_by_users, 0) <= :tl_requires_max_flagged AS flagged_by_users_criteria_met,
              COALESCE(topics_viewed_all_time, 0) AS topics_viewed_all_time,
              COALESCE(topics_viewed_all_time, 0) >= :tl_requires_topics_viewed_all_time AS all_time_topic_views_criteria_met,
              COALESCE(posts_read_all_time, 0) AS posts_read_all_time,
              COALESCE(posts_read_all_time, 0) >= :tl_requires_posts_read_all_time AS posts_read_all_time_criteria_met,
              COALESCE(num_likes_given, 0) AS num_likes_given,
              COALESCE(num_likes_given, 0) >= :tl_requires_likes_given AS likes_given_criteria_met,
              COALESCE(num_likes_received, 0) AS num_likes_received,
              COALESCE(num_likes_received, 0) >= :tl_requires_likes_received AS likes_received_criteria_met,
              COALESCE(num_likes_received_users, 0) AS num_likes_received_users,
              COALESCE(num_likes_received_users, 0) >= :tl_requires_likes_received::float / 4.0 AS likes_received_users_criteria_met,
              COALESCE(num_likes_received_days, 0) AS num_likes_received_days,
              COALESCE(num_likes_received_days, 0) >= (SELECT * FROM min_likes_received_days) AS likes_received_days_criteria_met
          FROM tl3_candidates c
          LEFT JOIN days_visited dv ON dv.user_id = c.user_id
          LEFT JOIN num_topics_replied_to ntr ON ntr.user_id = c.user_id
          LEFT JOIN topics_viewed tv ON tv.user_id = c.user_id
          LEFT JOIN posts_read pr ON pr.user_id = c.user_id
          LEFT JOIN num_flagged_posts nfp ON nfp.user_id = c.user_id
          LEFT JOIN num_flagged_by_users nfu ON nfu.user_id = c.user_id
          LEFT JOIN topics_viewed_all_time tvat ON tvat.user_id = c.user_id
          LEFT JOIN posts_read_all_time prat ON prat.user_id = c.user_id
          LEFT JOIN num_likes_given nlg ON nlg.user_id = c.user_id
          LEFT JOIN num_likes_received nlr ON nlr.user_id = c.user_id
      )
      SELECT * FROM candidate_results
      WHERE CASE WHEN :show_all_results THEN true ELSE visits_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE replies_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE topic_views_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE posts_read_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE flagged_post_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE flagged_by_users_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE all_time_topic_views_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE posts_read_all_time_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE likes_given_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE likes_received_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE likes_received_users_criteria_met END
          AND CASE WHEN :show_all_results THEN true ELSE likes_received_days_criteria_met END
      ORDER BY days_visited DESC
      SQL

      queries["silenced-users"]["sql"] = <<~SQL
      -- [params]
      -- null date :start_date
      -- null date :end_date
      -- null string :silenced_by

      SELECT
          silenced_users.id AS user_id,
          silenced_users.silenced_till AS silenced_till,
          COALESCE(staff.username, 'system') AS silenced_by,
          user_histories.created_at AS silenced_at
      FROM users silenced_users
      LEFT JOIN user_histories
          ON user_histories.target_user_id = silenced_users.id
          AND user_histories.action = 30 -- silence_user
      LEFT JOIN users staff
          ON staff.id = user_histories.acting_user_id
      WHERE silenced_users.silenced_till IS NOT NULL
          AND (:start_date IS NULL OR user_histories.created_at >= :start_date)
          AND (:end_date IS NULL OR user_histories.created_at <= :end_date)
          AND (
              :silenced_by IS NULL
              OR ((:silenced_by = 'system' AND staff.username IS NULL) OR staff.username = :silenced_by)
          )
      ORDER BY user_histories.created_at DESC
      SQL

      queries["user-warnings"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 28

      SELECT
          w.user_id AS warned_user_id,
          w.created_by_id AS warning_creator_user_id,
          w.topic_id,
          w.created_at
      FROM user_warnings w
      WHERE w.created_at >= CURRENT_DATE - :days_ago
      ORDER BY w.created_at DESC
      SQL

      queries["most-flagged-users"]["sql"] = <<~SQL
      SELECT
          p.user_id,
          COUNT(DISTINCT pa.post_id) AS flagged_posts,
          COUNT(*) AS agreed_flags
      FROM post_actions pa
      JOIN posts p ON pa.post_id = p.id
      WHERE pa.agreed_at IS NOT NULL
          AND p.user_id > 0
      GROUP BY p.user_id
      ORDER BY agreed_flags DESC, flagged_posts DESC
      LIMIT 100
      SQL

      queries["subcategory-permission-drift"]["sql"] = <<~SQL
      SELECT subcategories.* FROM (
          SELECT
              category.parent_category_id, category.id AS category_id, category.name AS category_name,
              category_group.permission_type,
              groups.name AS group_name, groups.id AS group_id
          FROM categories category
          INNER JOIN category_groups category_group ON category_group.category_id = category.id
          INNER JOIN groups ON groups.id = category_group.group_id
          WHERE parent_category_id IS NOT NULL
      ) subcategories
      LEFT JOIN (
          SELECT
              category.id AS category_id, category_group.permission_type,
              groups.id AS group_id
          FROM categories category
          INNER JOIN category_groups category_group ON category_group.category_id = category.id
          INNER JOIN groups ON groups.id = category_group.group_id
          WHERE parent_category_id IS NULL
      ) parent_categories
          ON parent_categories.category_id = subcategories.parent_category_id
          AND parent_categories.group_id = subcategories.group_id
          AND parent_categories.permission_type = subcategories.permission_type
      -- anti-join: keep only grants with no matching grant on the parent category
      WHERE parent_categories.category_id IS NULL
      SQL

      queries["reading-participation-histogram"]["sql"] = <<~SQL
      -- [params]
      -- int :from_days_ago = 0
      -- int :duration_days = 28

      WITH t AS (
          SELECT
              CURRENT_DATE::timestamp - ((:from_days_ago + :duration_days) * (INTERVAL '1 days')) AS period_start,
              CURRENT_DATE::timestamp - (:from_days_ago * (INTERVAL '1 days')) AS period_end
      ),
      read_visits AS (
          SELECT user_id, SUM(posts_read) AS posts_read
          FROM user_visits, t
          WHERE posts_read >= 1
              AND visited_at > t.period_start
              AND visited_at < t.period_end
          GROUP BY user_id
      )
      SELECT
          CASE
              WHEN posts_read <= 1 THEN '0001'
              WHEN posts_read <= 3 THEN '0002 - 0003'
              WHEN posts_read <= 7 THEN '0004 - 0007'
              WHEN posts_read <= 15 THEN '0008 - 0015'
              WHEN posts_read <= 31 THEN '0016 - 0031'
              WHEN posts_read <= 63 THEN '0032 - 0063'
              WHEN posts_read <= 127 THEN '0064 - 0127'
              WHEN posts_read <= 255 THEN '0128 - 0255'
              WHEN posts_read <= 511 THEN '0256 - 0511'
              WHEN posts_read <= 1023 THEN '0512 - 1023'
              WHEN posts_read <= 2047 THEN '1024 - 2047'
              ELSE '2048+'
          END AS posts_read_bucket,
          COUNT(*) AS num_users
      FROM read_visits
      GROUP BY posts_read_bucket
      ORDER BY posts_read_bucket
      SQL

      queries["flags-by-type"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 90

      SELECT
          COALESCE(f.name, 'score_type_' || rs.reviewable_score_type) AS flag_type,
          -- system and bot accounts have non-positive user ids
          COUNT(*) FILTER (WHERE rs.user_id > 0) AS reported_by_users,
          COUNT(*) FILTER (WHERE rs.user_id <= 0) AS automated,
          COUNT(*) AS total
      FROM reviewable_scores rs
      LEFT JOIN flags f ON f.id = rs.reviewable_score_type
      WHERE rs.created_at >= CURRENT_DATE - :days_ago
      GROUP BY 1
      ORDER BY total DESC
      SQL

      queries["flags-handled-by-staff"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 90

      SELECT
          rs.reviewed_by_id AS user_id,
          COUNT(*) AS flags_handled
      FROM reviewable_scores rs
      JOIN users u ON u.id = rs.reviewed_by_id
      WHERE (u.admin OR u.moderator)
          AND rs.reviewed_at >= CURRENT_DATE - :days_ago
      GROUP BY rs.reviewed_by_id
      ORDER BY flags_handled DESC
      LIMIT 100
      SQL

      queries["suspended-users"]["sql"] = <<~SQL
      -- [params]
      -- null date :start_date
      -- null date :end_date
      -- null string :suspended_by

      SELECT
          u.id AS user_id,
          u.suspended_at,
          u.suspended_till,
          COALESCE(staff.username, 'system') AS suspended_by,
          uh.created_at AS suspension_logged_at,
          uh.details
      FROM users u
      LEFT JOIN user_histories uh
          ON uh.target_user_id = u.id
          AND uh.action = 10 -- suspend_user
      LEFT JOIN users staff
          ON staff.id = uh.acting_user_id
      WHERE u.suspended_till IS NOT NULL
          AND (:start_date IS NULL OR uh.created_at >= :start_date)
          AND (:end_date IS NULL OR uh.created_at <= :end_date)
          AND (
              :suspended_by IS NULL
              OR ((:suspended_by = 'system' AND staff.username IS NULL) OR staff.username = :suspended_by)
          )
      ORDER BY uh.created_at DESC NULLS LAST
      SQL

      queries["foreign-language-topics"]["sql"] = <<~SQL
      -- [params]
      -- string :primary_locale = en
      -- int :days_ago = 30

      SELECT
          t.locale,
          t.id AS topic_id,
          t.category_id,
          t.created_at
      FROM topics t
      WHERE t.locale IS NOT NULL
          AND t.locale <> ''
          AND split_part(t.locale, '_', 1) <> split_part(:primary_locale, '_', 1)
          AND t.created_at >= CURRENT_DATE - :days_ago
          AND t.deleted_at IS NULL
      ORDER BY t.created_at DESC
      SQL

      queries["foreign-language-posts"]["sql"] = <<~SQL
      -- [params]
      -- string :primary_locale = en
      -- int :days_ago = 30

      SELECT
          p.locale,
          p.id AS post_id,
          p.topic_id,
          LEFT(p.raw, 100) AS excerpt,
          p.created_at
      FROM posts p
      WHERE p.locale IS NOT NULL
          AND p.locale <> ''
          AND split_part(p.locale, '_', 1) <> split_part(:primary_locale, '_', 1)
          AND p.created_at >= CURRENT_DATE - :days_ago
          AND p.deleted_at IS NULL
      ORDER BY p.created_at DESC
      SQL

      queries["crawler-traffic-overview"]["sql"] = <<~SQL
      -- [params]
      -- int :hours = 24

      WITH events AS (
          SELECT COALESCE(score, 0) AS score
          FROM browser_pageview_events
          WHERE created_at >= NOW() - (:hours * INTERVAL '1 hour')
      )
      SELECT 'Definitely user (0)' AS bucket, COUNT(*) FILTER (WHERE score = 0) AS pageviews FROM events
      UNION ALL
      SELECT 'Very likely user (1-40)', COUNT(*) FILTER (WHERE score BETWEEN 1 AND 40) FROM events
      UNION ALL
      SELECT 'Maybe crawler (41-99)', COUNT(*) FILTER (WHERE score BETWEEN 41 AND 99) FROM events
      UNION ALL
      SELECT 'Definitely crawler (100+)', COUNT(*) FILTER (WHERE score >= 100) FROM events
      SQL

      queries["crawler-traffic-detailed"]["sql"] = <<~SQL
      -- [params]
      -- int :hours = 24
      -- int :min_score = 40

      SELECT
          MAX(e.score) AS max_score,
          e.session_id,
          e.ip_address,
          e.user_id,
          e.user_agent,
          e.asn,
          e.country_code,
          COUNT(*) AS pageviews,
          MAX(s.automation_ua_score) AS automation_ua,
          MAX(s.known_asn_score) AS known_asn,
          MAX(s.velocity_score) AS velocity,
          MAX(s.churn_score) AS churn,
          MAX(s.rapid_nav_score) AS rapid_nav,
          MAX(s.referrer_score) AS referrer,
          NULLIF(
              CONCAT_WS(', ',
                  CASE WHEN MAX(s.automation_ua_score) > 0 THEN 'automation UA' END,
                  CASE WHEN MAX(s.known_asn_score) > 0 THEN 'known crawler ASN' END,
                  CASE WHEN MAX(s.velocity_score) > 0 THEN 'high velocity (+' || MAX(s.velocity_score) || ')' END,
                  CASE WHEN MAX(s.churn_score) > 0 THEN 'session churn (+' || MAX(s.churn_score) || ')' END,
                  CASE WHEN MAX(s.rapid_nav_score) > 0 THEN 'rapid navigation' END,
                  CASE WHEN MAX(s.referrer_score) > 0 THEN 'bad referrer (+' || MAX(s.referrer_score) || ')' END
              ),
              ''
          ) AS reasons
      FROM browser_pageview_events e
      JOIN browser_pageview_event_scores s ON s.event_id = e.id
      WHERE e.created_at >= NOW() - (:hours * INTERVAL '1 hour')
          AND e.score > :min_score
      GROUP BY e.ip_address, e.user_agent, e.asn, e.country_code, e.user_id, e.session_id
      ORDER BY max_score DESC, pageviews DESC
      SQL

      queries["suspected-bot-networks"]["sql"] = <<~SQL
      -- [params]
      -- int :days_ago = 3

      SELECT
          ip_address,
          asn,
          country_code,
          COUNT(*) AS pageviews,
          COUNT(DISTINCT session_id) AS sessions,
          ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT session_id), 0), 1) AS views_per_session,
          COUNT(DISTINCT user_agent) AS user_agents,
          COUNT(DISTINCT topic_id) FILTER (WHERE topic_id IS NOT NULL) AS topics_touched,
          -- network-wide total, so a scrape spread thin across many IPs
          -- on one network still sorts to the top
          SUM(COUNT(*)) OVER (PARTITION BY asn) AS asn_total_pageviews,
          MIN(created_at) AS first_seen,
          MAX(created_at) AS last_seen,
          (array_agg(user_agent ORDER BY created_at DESC))[1] AS sample_user_agent
      FROM browser_pageview_events
      WHERE created_at >= CURRENT_DATE - :days_ago
      GROUP BY ip_address, asn, country_code
      ORDER BY asn_total_pageviews DESC, pageviews DESC
      LIMIT 100
      SQL

      # convert query ids from "mostcommonlikers" to "-1", "mostmessages" to "-2" etc.
      queries.transform_keys!.with_index { |key, idx| "-#{idx + 1}" }
      queries
    end
  end
end
