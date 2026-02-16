# frozen_string_literal: true

Migrations::Database::Schema.table :categories do
  add_column :about_topic_title, :text
  add_column :existing_id, :numeric

  ignore :contains_messages
  ignore :latest_post_id
  ignore :latest_topic_id
  ignore :name_lower
  ignore :post_count
  ignore :posts_day
  ignore :posts_month
  ignore :posts_week
  ignore :posts_year
  ignore :topic_count
  ignore :topics_day
  ignore :topics_month
  ignore :topics_week
  ignore :topics_year
  ignore :reviewable_by_group_id
end
