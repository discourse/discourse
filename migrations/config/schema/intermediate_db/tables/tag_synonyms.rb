# frozen_string_literal: true

Migrations::Database::Schema.table :tag_synonyms do
  synthetic!

  primary_key :synonym_tag_id

  add_column :synonym_tag_id, :numeric
  add_column :target_tag_id, :numeric, required: true
end
