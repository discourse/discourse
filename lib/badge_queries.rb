module BadgeQueries
  Reader = <<SQL
  SELECT id user_id, current_timestamp granted_at
  FROM users
  WHERE id IN
  (
    SELECT pt.user_id
    FROM post_timings pt
    JOIN badge_posts b ON b.post_number = pt.post_number AND
                          b.topic_id = pt.topic_id
    JOIN topics t ON t.id = pt.topic_id
    LEFT JOIN user_badges ub ON ub.badge_id = 17 AND ub.user_id = pt.user_id
    WHERE ub.id IS NULL AND t.posts_count > 100
    GROUP BY pt.user_id, pt.topic_id, t.posts_count
    HAVING count(*) >= t.posts_count
  )
SQL

  ReadGuidelines = <<SQL
  SELECT user_id, read_faq granted_at
  FROM user_stats
  WHERE read_faq IS NOT NULL AND (user_id IN (:user_ids) OR :backfill)
SQL

  FirstQuote = <<SQL
  SELECT ids.user_id, q.post_id, q.created_at granted_at
  FROM
  (
    SELECT p1.user_id, MIN(q1.id) id
    FROM quoted_posts q1
    JOIN badge_posts p1 ON p1.id = q1.post_id
    JOIN badge_posts p2 ON p2.id = q1.quoted_post_id
    WHERE (:backfill OR ( p1.id IN (:post_ids) ))
    GROUP BY p1.user_id
  ) ids
  JOIN quoted_posts q ON q.id = ids.id
SQL

  FirstLink = <<SQL
  SELECT l.user_id, l.post_id, l.created_at granted_at
  FROM
  (
    SELECT MIN(l1.id) id
    FROM topic_links l1
    JOIN badge_posts p1 ON p1.id = l1.post_id
    JOIN badge_posts p2 ON p2.id = l1.link_post_id
    WHERE NOT reflection AND p1.topic_id <> p2.topic_id AND not quote AND
      (:backfill OR ( p1.id in (:post_ids) ))
    GROUP BY l1.user_id
  ) ids
  JOIN topic_links l ON l.id = ids.id
SQL

  FirstShare = <<SQL
  SELECT views.user_id, i2.post_id, i2.created_at granted_at
  FROM
  (
    SELECT i.user_id, MIN(i.id) i_id
    FROM incoming_links i
    JOIN badge_posts p on p.id = i.post_id
    WHERE i.user_id IS NOT NULL
    GROUP BY i.user_id
  ) as views
  JOIN incoming_links i2 ON i2.id = views.i_id
SQL

  FirstFlag = <<SQL
  SELECT pa1.user_id, pa1.created_at granted_at, pa1.post_id
  FROM (
    SELECT pa.user_id, min(pa.id) id
    FROM post_actions pa
    JOIN badge_posts p on p.id = pa.post_id
    WHERE post_action_type_id IN (#{PostActionType.flag_types_without_custom.values.join(",")}) AND
      (:backfill OR pa.post_id IN (:post_ids) )
    GROUP BY pa.user_id
  ) x
  JOIN post_actions pa1 on pa1.id = x.id
SQL

  FirstLike = <<SQL
  SELECT pa1.user_id, pa1.created_at granted_at, pa1.post_id
  FROM (
    SELECT pa.user_id, min(pa.id) id
    FROM post_actions pa
    JOIN badge_posts p on p.id = pa.post_id
    WHERE post_action_type_id = 2 AND
      (:backfill OR pa.post_id IN (:post_ids) )
    GROUP BY pa.user_id
  ) x
  JOIN post_actions pa1 on pa1.id = x.id
SQL

  # Incorrect, but good enough - (earlies post edited vs first edit)
  Editor = <<SQL
  SELECT p.user_id, min(p.id) post_id, min(p.created_at) granted_at
  FROM badge_posts p
  WHERE p.self_edits > 0 AND
      (:backfill OR p.id IN (:post_ids) )
  GROUP BY p.user_id
SQL

  WikiEditor = <<~SQL
  SELECT DISTINCT ON (pr.user_id) pr.user_id, pr.post_id, pr.created_at granted_at
  FROM post_revisions pr
  JOIN badge_posts p on p.id = pr.post_id
  WHERE p.wiki
      AND NOT pr.hidden
      AND (:backfill OR p.id IN (:post_ids))
SQL

  Welcome = <<SQL
  SELECT p.user_id, min(post_id) post_id, min(pa.created_at) granted_at
  FROM post_actions pa
  JOIN badge_posts p on p.id = pa.post_id
  WHERE post_action_type_id = 2 AND
      (:backfill OR pa.post_id IN (:post_ids) )
  GROUP BY p.user_id
SQL

  Autobiographer = <<SQL
  SELECT u.id user_id, current_timestamp granted_at
  FROM users u
  JOIN user_profiles up on u.id = up.user_id
  WHERE bio_raw IS NOT NULL AND LENGTH(TRIM(bio_raw)) > #{Badge::AutobiographerMinBioLength} AND
        uploaded_avatar_id IS NOT NULL AND
        (:backfill OR u.id IN (:user_ids) )
SQL

  FirstMention = <<-SQL
  SELECT acting_user_id AS user_id, min(target_post_id) AS post_id, min(p.created_at) AS granted_at
  FROM user_actions
  JOIN posts p ON p.id = target_post_id
  JOIN topics t ON t.id = topic_id
  JOIN categories c on c.id = category_id
  WHERE action_type = 7
    AND NOT read_restricted
    AND p.deleted_at IS  NULL
    AND t.deleted_at IS  NULL
    AND t.visible
    AND t.archetype <> 'private_message'
    AND (:backfill OR p.id IN (:post_ids))
  GROUP BY acting_user_id
SQL

  def self.invite_badge(count, trust_level)
    "
      SELECT u.id user_id, current_timestamp granted_at
      FROM users u
      WHERE u.id IN (
        SELECT invited_by_id
        FROM invites i
        JOIN users u2 ON u2.id = i.user_id
        WHERE i.deleted_at IS NULL AND u2.active AND u2.trust_level >= #{trust_level.to_i} AND u2.silenced_till IS NULL
        GROUP BY invited_by_id
        HAVING COUNT(*) >= #{count.to_i}
      ) AND u.active AND u.silenced_till IS NULL AND u.id > 0 AND
        (:backfill OR u.id IN (:user_ids) )
    "
  end

  def self.like_badge(count, is_topic)
    # we can do better with dates, but its hard work
    "
      SELECT p.user_id, p.id post_id, p.updated_at granted_at
      FROM badge_posts p
      WHERE #{is_topic ? "p.post_number = 1" : "p.post_number > 1" } AND p.like_count >= #{count.to_i} AND
        (:backfill OR p.id IN (:post_ids) )
    "
  end

  def self.trust_level(level)
    # we can do better with dates, but its hard work figuring this out historically
    "
      SELECT u.id user_id, current_timestamp granted_at FROM users u
      WHERE trust_level >= #{level.to_i} AND (
        :backfill OR u.id IN (:user_ids)
      )
    "
  end

  def self.sharing_badge(count)
    <<SQL
  SELECT views.user_id, i2.post_id, current_timestamp granted_at
  FROM
  (
    SELECT i.user_id, MIN(i.id) i_id
    FROM incoming_links i
    JOIN badge_posts p on p.id = i.post_id
    WHERE i.user_id IS NOT NULL
    GROUP BY i.user_id,i.post_id
    HAVING COUNT(*) > #{count}
  ) as views
  JOIN incoming_links i2 ON i2.id = views.i_id
SQL
  end

  def self.linking_badge(count)
    <<-SQL
        SELECT tl.user_id, post_id, current_timestamp granted_at
          FROM topic_links tl
          JOIN badge_posts p ON p.id = post_id
         WHERE NOT tl.internal
           AND tl.clicks >= #{count}
      GROUP BY tl.user_id, tl.post_id
    SQL
  end

  def self.liked_posts(post_count, like_count)
    <<-SQL
      SELECT p.user_id, current_timestamp AS granted_at
      FROM posts AS p
      WHERE p.like_count >= #{like_count}
        AND (:backfill OR p.user_id IN (:user_ids))
      GROUP BY p.user_id
      HAVING count(*) > #{post_count}
    SQL
  end

  def self.like_rate_limit(count)
    <<-SQL
      SELECT gdl.user_id, current_timestamp AS granted_at
      FROM given_daily_likes AS gdl
      WHERE gdl.limit_reached
        AND (:backfill OR gdl.user_id IN (:user_ids))
      GROUP BY gdl.user_id
      HAVING COUNT(*) >= #{count}
    SQL
  end

  def self.liked_back(likes_received, likes_given)
    <<-SQL
      SELECT us.user_id, current_timestamp AS granted_at
      FROM user_stats AS us
      INNER JOIN posts AS p ON p.user_id = us.user_id
      WHERE p.like_count > 0
        AND us.likes_given >= #{likes_given}
        AND (:backfill OR us.user_id IN (:user_ids))
      GROUP BY us.user_id, us.likes_given
      HAVING COUNT(*) > #{likes_received}
    SQL
  end

  def self.consecutive_visits(days)
    <<~SQL
      WITH consecutive_visits AS (
        SELECT user_id
             , visited_at
             , visited_at - (DENSE_RANK() OVER (PARTITION BY user_id ORDER BY visited_at))::int s
          FROM user_visits
      ), visits AS (
        SELECT user_id
             , MIN(visited_at) "start"
             , DENSE_RANK() OVER (PARTITION BY user_id ORDER BY s) "rank"
          FROM consecutive_visits
      GROUP BY user_id, s
        HAVING COUNT(*) >= #{days}
      )
      SELECT user_id
           , "start" + interval '#{days} days' "granted_at"
        FROM visits
       WHERE "rank" = 1
    SQL
  end

end
