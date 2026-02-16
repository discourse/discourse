# frozen_string_literal: true

Migrations::Database::Schema.table :user_options do
  include_all
  primary_key :user_id
end
