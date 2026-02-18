# frozen_string_literal: true

Migrations::Database::Schema.table :tags do
  ignore :pm_topic_count, :public_topic_count, :staff_topic_count, reason: "Calculated columns"

  ignore :target_tag_id, reason: "We have the `tag_synonyms` table for this"
end
