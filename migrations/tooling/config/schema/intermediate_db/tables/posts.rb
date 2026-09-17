# frozen_string_literal: true

Migrations::Tooling::Schema.table :posts do
  index :topic_id, :post_number

  # `raw` holds the body with placeholders, `original_raw` the untouched
  # source body.
  add_column :original_raw, :text

  # Resolved to the parent post's `original_id` by the converter.
  column :reply_to_post_number, rename_to: :reply_to_post_id

  column :post_type, :post_type
  column :hidden_reason_id, :post_hidden_reason

  # Post numbers are recomputed at import time, so the source value is optional.
  column :post_number, required: false

  # Every converted post is Markdown, so the importer leaves `cook_method` at
  # `regular`. A `raw_html` or `email` post skips markdown-it at cook time, and
  # none of the markdown the resolver splices in would render. Support that
  # together with an HTML mode in the resolver, not before.
  ignore :cook_method, reason: "Fixed at regular until non-Markdown posts are a designed feature"

  ignore :baked_at,
         :baked_version,
         :bookmark_count,
         :cooked,
         :edit_reason,
         :illegal_count,
         :image_upload_id,
         :inappropriate_count,
         :incoming_link_count,
         :last_version_at,
         :like_score,
         :notify_moderators_count,
         :notify_user_count,
         :off_topic_count,
         :outbound_message_id,
         :percent_rank,
         :public_version,
         :qa_vote_count,
         :quote_count,
         :raw_email,
         :reads,
         :reply_count,
         :reply_quoted,
         :score,
         :self_edits,
         :spam_count,
         :version,
         :via_email,
         :word_count,
         reason: "Calculated or unused columns"
end
