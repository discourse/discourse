# frozen_string_literal: true

first_solution_query = <<~SQL
  SELECT post_id, user_id, created_at AS granted_at
  FROM (
           SELECT p.id AS post_id, p.user_id, dsst.created_at,
              ROW_NUMBER() OVER (PARTITION BY p.user_id ORDER BY dsst.created_at) AS row_number
           FROM discourse_solved_solved_topics dsst
              JOIN badge_posts p ON dsst.answer_post_id = p.id
              JOIN topics t ON p.topic_id = t.id
           WHERE p.user_id <> t.user_id -- ignore topics solved by OP
              AND (:backfill OR p.id IN (:post_ids))
       ) x
  WHERE row_number = 1
SQL

Badge.seed(:name) do |badge|
  badge.name = "Solved 1"
  badge.default_icon = "square-check"
  badge.badge_type_id = BadgeType::Bronze
  badge.default_badge_grouping_id = BadgeGrouping::Community
  badge.query = first_solution_query
  badge.listable = true
  badge.target_posts = true
  badge.default_enabled = false
  badge.trigger = Badge::Trigger::PostRevision
  badge.auto_revoke = true
  badge.show_posts = true
  badge.system = true
end

def solved_query_with_count(min_count)
  <<~SQL
    SELECT p.user_id, MAX(dsst.created_at) AS granted_at
    FROM discourse_solved_solved_topics dsst
         JOIN badge_posts p ON dsst.answer_post_id = p.id
         JOIN topics t ON p.topic_id = t.id
    WHERE p.user_id <> t.user_id -- ignore topics solved by OP
      AND (:backfill OR p.id IN (:post_ids))
    GROUP BY p.user_id
    HAVING COUNT(*) >= #{min_count}
  SQL
end

[
  ["Solved 2", BadgeType::Silver, 10],
  ["Solved 3", BadgeType::Gold, 50],
  ["Solved 4", BadgeType::Gold, 150],
].each do |name, level, count|
  Badge.seed(:name) do |badge|
    badge.name = name
    badge.default_icon = "square-check"
    badge.badge_type_id = level
    badge.default_badge_grouping_id = BadgeGrouping::Community
    badge.query = solved_query_with_count(count)
    badge.listable = true
    badge.default_allow_title = true
    badge.target_posts = false
    badge.default_enabled = false
    badge.trigger = Badge::Trigger::PostRevision
    badge.auto_revoke = true
    badge.show_posts = false
    badge.system = true
  end
end
