# frozen_string_literal: true

Migrations::Database::Schema.table :users do
  add_column :original_username, :text
  add_column :avatar_type, :integer

  column :created_at, required: true

  ignore :flag_level, "TODO: add reason"
  ignore :last_emailed_at, "TODO: add reason"
  ignore :last_posted_at, "TODO: add reason"
  ignore :last_seen_reviewable_id, "TODO: add reason"
  ignore :previous_visit_at, "TODO: add reason"
  ignore :required_fields_version, "TODO: add reason"
  ignore :secure_identifier, "TODO: add reason"
  ignore :seen_notification_id, "TODO: add reason"
  ignore :suspended_at, "TODO: add reason"
  ignore :suspended_till, "TODO: add reason"
  ignore :username_lower, "TODO: add reason"
end
