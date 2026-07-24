# frozen_string_literal: true

Migrations::Tooling::Schema.table :permalink_normalizations do
  synthetic!

  primary_key :normalization

  add_column :normalization, :text
end
