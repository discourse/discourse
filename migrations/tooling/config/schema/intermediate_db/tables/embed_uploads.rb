# frozen_string_literal: true

# Upload embeds. `upload_id` points at a row in the `uploads` table. The importer
# reads that upload's `upload://...` markdown from the uploads store and puts it in
# the owner's markdown. `placeholder` holds the token spliced into the owner's
# markdown (a post body today, a user bio etc. later); see `Migrations::Placeholder`.
# `owner_type`/`owner_id` name that owning record.
#
# NOTE: `upload_id` is `:text`, not `:numeric`. Upload `original_id`s in the
# IntermediateDB are content hashes (see `uploads.id`, also `:text`). This matches
# the global `.*upload.*_id$ => :text` convention, so the reference must be text too.
Migrations::Tooling::Schema.table :embed_uploads do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :upload_id, :text

  index :owner_type, :owner_id
end
