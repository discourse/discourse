# frozen_string_literal: true

# One result row per IntermediateDB `upload_sources` row, keyed by the same XXH3
# hash. `upload_id` points at `uploads.id` (staging PK) and is NULL when the
# source was skipped or failed; several results can share one upload via sha1
# dedup. `markdown` is precomputed per-source because it embeds the source
# description. `status` and `skip_reason` use string enums so ad-hoc SQL stays
# greppable (e.g. `skip_reason = 'download_error'`).
Migrations::Tooling::Schema.table :upload_results do
  synthetic!

  primary_key :id

  add_column :id, :text
  add_column :upload_id, :integer
  add_column :markdown, :text
  add_column :status, :text, enum: :upload_result_status, required: true
  add_column :skip_reason, :text, enum: :upload_skip_reason
  add_column :skip_details, :text

  # The import step's optimized_images join and the cleanup cascades probe by
  # upload_id; without this SQLite falls back to per-statement automatic indexes.
  index :upload_id, where: "upload_id IS NOT NULL"
end
