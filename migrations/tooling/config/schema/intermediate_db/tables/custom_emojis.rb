# frozen_string_literal: true

# Custom emoji defined on the source site. `name` is the shortcode (without the
# surrounding colons); a post's `:name:` renders this emoji when `name` matches.
#
# `upload_id` is the emoji image. The source stores it as a numeric FK into
# `uploads`, but IntermediateDB references an upload by its content hash, so the
# step resolves the FK to the upload's `sha1` in its `items` query. The global
# `.*upload.*_id$ => :text` convention already types this column as text to match.
Migrations::Tooling::Schema.table :custom_emojis do
  ignore :user_id, reason: "The uploader isn't needed to recreate the emoji"
end
