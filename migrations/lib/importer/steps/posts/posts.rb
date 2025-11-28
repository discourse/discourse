# frozen_string_literal: true

module Migrations::Importer::Steps
  class Posts < ::Migrations::Importer::CopyStep
    POST_TYPES = Post.types.values.to_set.freeze
    DEFAULT_POST_TYPE = Post.types[:regular]
    HIDDEN_REASONS = Post.hidden_reasons.values.to_set.freeze
    EMPTY_POST_RAW = "<Empty imported post>"

    depends_on :topics, :users
    store_mapped_ids true

    column_names %i[
                   id
                   user_id
                   topic_id
                   post_number
                   raw
                   cooked
                   created_at
                   updated_at
                   reply_to_post_number
                   deleted_at
                   like_count
                   post_type
                   sort_order
                   last_editor_id
                   hidden
                   hidden_reason_id
                   last_version_at
                   user_deleted
                   reply_to_user_id
                   deleted_by_id
                   word_count
                   wiki
                   hidden_at
                   action_code
                   locked_by_id
                   locale
                 ]

    total_rows_query <<~SQL, MappingType::POSTS, MappingType::TOPICS
      SELECT COUNT(*)
      FROM posts
           JOIN mapped.ids mapped_topic
             ON posts.topic_id = mapped_topic.original_id AND mapped_topic.type = ?2
           LEFT JOIN mapped.ids mapped_post
             ON posts.original_id = mapped_post.original_id AND mapped_post.type = ?1
      WHERE mapped_post.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::POSTS, MappingType::TOPICS, MappingType::USERS
      SELECT posts.*,
             reply_post.post_number                AS reply_to_post_number,
             mapped_topic.discourse_id             AS discourse_topic_id,
             mapped_user.discourse_id              AS discourse_user_id,
             mapped_reply_to_user.discourse_id     AS discourse_reply_to_user_id,
             mapped_last_editor.discourse_id       AS discourse_last_editor_id,
             mapped_deleted_by_user.discourse_id   AS discourse_deleted_by_user_id,
             mapped_locked_by_user.discourse_id    AS discourse_locked_by_user_id
        FROM posts
             JOIN mapped.ids mapped_topic
               ON posts.topic_id = mapped_topic.original_id AND mapped_topic.type = ?2
             LEFT JOIN mapped.ids mapped_post
               ON posts.original_id = mapped_post.original_id AND mapped_post.type = ?1
             LEFT JOIN posts reply_post
               ON posts.reply_to_post_id = reply_post.original_id
             LEFT JOIN mapped.ids mapped_user
               ON posts.user_id = mapped_user.original_id AND mapped_user.type = ?3
             LEFT JOIN mapped.ids mapped_reply_to_user
               ON posts.reply_to_user_id = mapped_reply_to_user.original_id AND mapped_reply_to_user.type = ?3
             LEFT JOIN mapped.ids mapped_last_editor
               ON posts.last_editor_id = mapped_last_editor.original_id AND mapped_last_editor.type = ?3
             LEFT JOIN mapped.ids mapped_deleted_by_user
               ON posts.deleted_by_id = mapped_deleted_by_user.original_id AND mapped_deleted_by_user.type = ?3
             LEFT JOIN mapped.ids mapped_locked_by_user
               ON posts.locked_by_id = mapped_locked_by_user.original_id AND mapped_locked_by_user.type = ?3
       WHERE mapped_post.original_id IS NULL
       ORDER BY posts.topic_id, posts.post_number, posts.original_id
    SQL

    private

    def transform_row(row)
      row[:topic_id] = row[:discourse_topic_id]
      row[:user_id] = row[:discourse_user_id] || SYSTEM_USER_ID
      row[:reply_to_user_id] = row[:discourse_reply_to_user_id]
      row[:last_editor_id] = row[:discourse_last_editor_id]
      row[:deleted_by_id] = row[:discourse_deleted_by_user_id]
      row[:locked_by_id] = row[:discourse_locked_by_user_id]

      row[:post_type] = ensure_valid_value(
        value: row[:post_type],
        allowed_set: POST_TYPES,
        default_value: DEFAULT_POST_TYPE,
      )

      row[:hidden] = false if row[:hidden].nil?
      row[:user_deleted] = false if row[:user_deleted].nil?
      row[:wiki] = false if row[:wiki].nil?

      if row[:hidden] && row[:hidden_reason_id]
        row[:hidden_reason_id] = ensure_valid_value(
          value: row[:hidden_reason_id],
          allowed_set: HIDDEN_REASONS,
          default_value: nil,
        )

        row[:hidden_at] ||= row[:updated_at]
      end

      row[:raw] = row[:raw]&.scrub&.strip.presence || EMPTY_POST_RAW

      # TODO(selase): Incomplete, temporary stand-in until we have a parser
      row[:cooked] = PrettyText.cook(row[:raw])
      row[:like_count] ||= 0
      row[:last_version_at] ||= row[:created_at]

      super
    end
  end
end
