# frozen_string_literal: true

Migrations::Database::Schema.table :uploads do
  model :manual

  synthetic!

  primary_key :id

  add_column :id, :text
  add_column :filename, :text, required: true
  add_column :path, :text
  add_column :data, :blob
  add_column :url, :text
  add_column :type, :text, enum: :upload_type
  add_column :description, :text
  add_column :origin, :text
  add_column :user_id, :numeric
end
