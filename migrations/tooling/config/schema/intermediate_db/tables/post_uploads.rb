# frozen_string_literal: true

# Upload embeds. `upload_id` points at a row in the `uploads` table. The importer
# reads that upload's `upload://...` markdown from the uploads store and puts it in
# the post body. `placeholder` holds the token put in `post.raw`; see
# `Migrations::Placeholder`.
#
# NOTE: `upload_id` is `:blob`, not `:numeric`. Upload `original_id`s in the
# IntermediateDB are content hashes stored as 16-byte blobs (see `upload_sources.id`,
# also `:blob`). This matches the global `.*upload.*_id$ => :blob` convention, so the
# reference must be a blob too.
Migrations::Tooling::Schema.table :post_uploads do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :upload_id, :blob

  index :post_id
end
