# frozen_string_literal: true

# Mirrors Discourse's `optimized_images`. `id` is the staging PK, `upload_id`
# points at the staging `uploads.id`.
Migrations::Tooling::Schema.table :optimized_images do
  include_all

  # The optimizer's already-done detection is `SELECT DISTINCT upload_id`; the
  # index turns that into an index scan.
  index :upload_id
end
