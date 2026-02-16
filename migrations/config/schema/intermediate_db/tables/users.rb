# frozen_string_literal: true

Migrations::Database::Schema.table :users do
  add_column :original_username, :text
  add_column :avatar_type, :integer

  column :created_at, required: true

  ignore :flag_level
  ignore :last_emailed_at
  ignore :last_posted_at
  ignore :last_seen_reviewable_id
  ignore :previous_visit_at
  ignore :required_fields_version
  ignore :secure_identifier
  ignore :seen_notification_id
  ignore :suspended_at
  ignore :suspended_till
  ignore :username_lower
end
