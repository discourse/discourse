# frozen_string_literal: true

# Download-cache index, keyed by the source hash.
Migrations::Tooling::Schema.table :downloads do
  synthetic!

  primary_key :id

  add_column :id, :text
  add_column :original_filename, :text, required: true
end
