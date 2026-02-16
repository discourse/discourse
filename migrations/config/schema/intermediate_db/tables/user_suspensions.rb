# frozen_string_literal: true

Migrations::Database::Schema.table :user_suspensions do
  synthetic!
  primary_key :user_id, :suspended_at
  add_column :user_id, :numeric, required: true
  add_column :suspended_at, :datetime, required: true
  add_column :suspended_till, :datetime
  add_column :suspended_by_id, :numeric
  add_column :reason, :text
end
