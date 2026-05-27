# frozen_string_literal: true

Migrations::Database::Schema.table :users do
  primary_key :id

  include :id, :username, :email, :created_at

  column :email, :text, required: true

  add_column :existing_id, :numeric

  ignore :admin_notes, reason: "Not needed for migration"

  index :username, unique: true
  check :email_format, "email LIKE '%@%'"
end
