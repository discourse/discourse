# frozen_string_literal: true

module ::DiscourseDataExplorer
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

      # convert query ids from "mostcommonlikers" to "-1", "mostmessages" to "-2" etc.
      queries.transform_keys!.with_index { |key, idx| "-#{idx + 1}" }
      queries
    end
  end
end
