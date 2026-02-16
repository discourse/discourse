# frozen_string_literal: true

Migrations::Database::Schema.table :categories do
  add_column :about_topic_title, :text
  add_column :existing_id, :numeric

  ignore :contains_messages,
         :reviewable_by_group_id,
         reason: "TODO: Figure out what these columns are for and if we need them"

  ignore :latest_post_id,
         :latest_topic_id,
         :name_lower,
         :post_count,
         :posts_day,
         :posts_month,
         :posts_week,
         :posts_year,
         :topic_count,
         :topics_day,
         :topics_month,
         :topics_week,
         :topics_year,
         reason: "Calculated columns"
end
