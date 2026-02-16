# frozen_string_literal: true

Migrations::Database::Schema.table :categories do
  add_column :about_topic_title, :text
  add_column :existing_id, :numeric

  ignore :contains_messages, "TODO: add reason"
  ignore :latest_post_id, "TODO: add reason"
  ignore :latest_topic_id, "TODO: add reason"
  ignore :name_lower, "TODO: add reason"
  ignore :post_count, "TODO: add reason"
  ignore :posts_day, "TODO: add reason"
  ignore :posts_month, "TODO: add reason"
  ignore :posts_week, "TODO: add reason"
  ignore :posts_year, "TODO: add reason"
  ignore :topic_count, "TODO: add reason"
  ignore :topics_day, "TODO: add reason"
  ignore :topics_month, "TODO: add reason"
  ignore :topics_week, "TODO: add reason"
  ignore :topics_year, "TODO: add reason"
  ignore :reviewable_by_group_id, "TODO: add reason"
end
