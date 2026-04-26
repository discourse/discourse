# frozen_string_literal: true

Migrations::Database::Schema.table :users do
  add_column :original_username, :text
  add_column :avatar_type, :integer

  column :created_at, required: true

  ignore :flag_level,
         :last_emailed_at,
         :last_posted_at,
         :last_seen_reviewable_id,
         :previous_visit_at,
         :required_fields_version,
         :secure_identifier,
         :seen_notification_id,
         :username_lower,
         reason: "Calculated columns"

  ignore :suspended_at, :suspended_till, reason: "We have the `user_suspensions` table for this"
end
