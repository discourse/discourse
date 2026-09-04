# frozen_string_literal: true

# Upload embeds. `upload_id` points at a row in the `uploads` table. The importer
# reads that upload's `upload://...` markdown from the uploads store and puts it in
# the owner's markdown. `placeholder` holds the token spliced into the owner's
# markdown (a post body today, a user bio etc. later); see `Migrations::Placeholder`.
# `owner_type`/`owner_id` name that owning record.
#
# `original_markdown` is the verbatim source snippet for both a full URL
# (`/uploads/.../<sha1>.png`) and a short `upload://` reference. When the id maps
# to no Discourse upload, the importer puts this snippet back unchanged instead
# of dropping the embed — a hotlink to another forum's upload then survives as-is.
#
# `external_host` is set when a full-URL upload points at a host the conversion does
# not recognize as the source's own. A foreign URL whose 40-hex basename happens to
# collide with a source upload sha1 must not be rewritten to the imported file, so
# the importer maps such a row only when the conversion explicitly allowlists the
# host (a CDN, an old S3 bucket) — otherwise the verbatim snippet is restored.
#
# NOTE: `upload_id` is `:text`, not `:numeric`. Upload `original_id`s in the
# IntermediateDB are content hashes (see `uploads.id`, also `:text`). This matches
# the global `.*upload.*_id$ => :text` convention, so the reference must be text too.
# `original_markdown` is not an id, so the convention does not apply to it.
Migrations::Tooling::Schema.table :embed_uploads do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :external_host, :text
  add_column :placeholder, :text, required: true
  add_column :upload_id, :text
  add_column :original_markdown, :text

  index :owner_type, :owner_id
end
