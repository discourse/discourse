# frozen_string_literal: true

# Mirrors Discourse's `optimized_images`. `id` is the migration-environment PK,
# and `upload_id` points at the migration environment's `uploads.id`.
Migrations::Tooling::Schema.table :optimized_images do
  include_all

  # The optimizer loads every distinct `upload_id` at startup. This index lets
  # SQLite read those ids without scanning the full table.
  index :upload_id
end
