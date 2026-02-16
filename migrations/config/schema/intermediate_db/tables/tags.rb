# frozen_string_literal: true

Migrations::Database::Schema.table :tags do
  ignore :pm_topic_count
  ignore :public_topic_count
  ignore :staff_topic_count
  ignore :target_tag_id
end
