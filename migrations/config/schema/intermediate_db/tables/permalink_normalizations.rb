# frozen_string_literal: true

Migrations::Database::Schema.table :permalink_normalizations do
  synthetic!

  primary_key :normalization

  add_column :normalization, :text
end
