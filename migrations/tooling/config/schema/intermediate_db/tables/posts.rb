# frozen_string_literal: true

Migrations::Tooling::Schema.table :posts do
  index :topic_id, :post_number

  # The finalized `raw` is rebuilt at import time; `original_raw` keeps the
  # untouched source body alongside the placeholder-substituted `raw`.
  add_column :original_raw, :text

  # `reply_to_post_number` is resolved to the parent post's `original_id` in the
  # converter, so it's stored as a post reference rather than a number.
  column :reply_to_post_number, rename_to: :reply_to_post_id

  column :post_type, :post_type
  column :hidden_reason_id, :post_hidden_reason

  # Post numbers are recomputed at import time, so the source value is optional.
  column :post_number, required: false

  ignore :baked_at,
         :baked_version,
         :bookmark_count,
         :cook_method,
         :cooked,
         :edit_reason,
         :illegal_count,
         :image_upload_id,
         :inappropriate_count,
         :incoming_link_count,
         :last_version_at,
         :like_score,
         :locale,
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
