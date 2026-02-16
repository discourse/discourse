# frozen_string_literal: true

Migrations::Database::Schema.table :log_entries do
  model :manual

  synthetic!

  add_column :created_at, :datetime, required: true
  add_column :type, :text, required: true, enum: :log_entry_type
  add_column :message, :text, required: true
  add_column :exception, :text
  add_column :details, :json
end
