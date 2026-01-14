# frozen_string_literal: true

first_reaction_query = <<~SQL
  SELECT user_id, created_at AS granted_at, post_id
  FROM (
           SELECT ru.post_id, ru.user_id, ru.created_at,
                  ROW_NUMBER() OVER (PARTITION BY ru.user_id ORDER BY ru.created_at) AS row_number
           FROM discourse_reactions_reaction_users ru
                JOIN badge_posts p ON ru.post_id = p.id
           WHERE :backfill
              OR ru.post_id IN (:post_ids)
       ) x
  WHERE row_number = 1
SQL

Badge.seed(:name) do |b|
  b.name = "First Reaction"
  b.default_icon = "face-smile"
  b.badge_type_id = BadgeType::Bronze
  b.multiple_grant = false
  b.target_posts = true
  b.show_posts = true
  b.query = first_reaction_query
  b.default_badge_grouping_id = BadgeGrouping::GettingStarted
  b.trigger = Badge::Trigger::PostRevision
  b.system = true
end
