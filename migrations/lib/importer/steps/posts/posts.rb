# frozen_string_literal: true

module Migrations::Importer::Steps
  class Posts < ::Migrations::Importer::CopyStep
    POST_TYPES = Post.types.values.to_set.freeze
    DEFAULT_POST_TYPE = Post.types[:regular]
    SMALL_ACTION_TYPE = Post.types[:small_action]
    MODERATOR_ACTION_TYPE = Post.types[:moderator_action]
    HIDDEN_REASONS = Post.hidden_reasons.values.to_set.freeze
    EMPTY_POST_RAW = "<Empty imported post>"
    BLANK_POST_RAW = ""

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
      WITH importable_posts AS (
        SELECT posts.*,
               mapped_topic.discourse_id  AS discourse_topic_id
          FROM posts
               JOIN mapped.ids mapped_topic
                 ON posts.topic_id = mapped_topic.original_id AND mapped_topic.type = ?2
               LEFT JOIN mapped.ids mapped_post
                 ON posts.original_id = mapped_post.original_id AND mapped_post.type = ?1
        WHERE mapped_post.original_id IS NULL
      ),
      normalized_posts AS (
        SELECT original_id,
               ROW_NUMBER() OVER (
                 PARTITION BY topic_id
                 ORDER BY created_at, original_id
               ) AS computed_post_number
        FROM importable_posts
      )
      SELECT importable_posts.*,
             normalized_posts.computed_post_number       AS computed_post_number,
             parent_normalized_post.computed_post_number AS reply_to_post_number,
             importable_posts.discourse_topic_id         AS discourse_topic_id,
             mapped_user.discourse_id                    AS discourse_user_id,
             mapped_reply_to_user.discourse_id           AS discourse_reply_to_user_id,
             mapped_last_editor.discourse_id             AS discourse_last_editor_id,
             mapped_deleted_by_user.discourse_id         AS discourse_deleted_by_user_id,
             mapped_locked_by_user.discourse_id          AS discourse_locked_by_user_id
        FROM importable_posts
             JOIN normalized_posts
               ON importable_posts.original_id = normalized_posts.original_id
             LEFT JOIN importable_posts reply_post
               ON importable_posts.reply_to_post_id = reply_post.original_id
             LEFT JOIN normalized_posts parent_normalized_post
               ON reply_post.original_id = parent_normalized_post.original_id
             LEFT JOIN mapped.ids mapped_user
               ON importable_posts.user_id = mapped_user.original_id AND mapped_user.type = ?3
             LEFT JOIN mapped.ids mapped_reply_to_user
               ON importable_posts.reply_to_user_id = mapped_reply_to_user.original_id AND mapped_reply_to_user.type = ?3
             LEFT JOIN mapped.ids mapped_last_editor
               ON importable_posts.last_editor_id = mapped_last_editor.original_id AND mapped_last_editor.type = ?3
             LEFT JOIN mapped.ids mapped_deleted_by_user
               ON importable_posts.deleted_by_id = mapped_deleted_by_user.original_id AND mapped_deleted_by_user.type = ?3
             LEFT JOIN mapped.ids mapped_locked_by_user
               ON importable_posts.locked_by_id = mapped_locked_by_user.original_id AND mapped_locked_by_user.type = ?3
       ORDER BY importable_posts.topic_id, normalized_posts.computed_post_number
    SQL

    private

    def setup
      load_existing_max_post_numbers
    end

    def transform_row(row)
      topic_id = row[:discourse_topic_id]

      row[:topic_id] = topic_id
      row[:user_id] = row[:discourse_user_id] || SYSTEM_USER_ID
      row[:reply_to_user_id] = row[:discourse_reply_to_user_id]
      row[:last_editor_id] = row[:discourse_last_editor_id]
      row[:deleted_by_id] = row[:discourse_deleted_by_user_id]
      row[:locked_by_id] = row[:discourse_locked_by_user_id]

      existing_max_post_number = @max_post_number_by_topic_id[topic_id]
      row[:post_number] = existing_max_post_number + row[:computed_post_number]

      # TODO(selase): Handle replies to existing posts
      if row[:reply_to_post_number]
        row[:reply_to_post_number] = existing_max_post_number + row[:reply_to_post_number]
      end

      row[:post_type] = ensure_valid_value(
        value: row[:post_type],
        allowed_set: POST_TYPES,
        default_value: DEFAULT_POST_TYPE,
      ) do |value, default_value|
        puts "   #{row[:original_id]}: Post type '#{value}' is invalid, defaulting to #{default_value}"
      end

      row[:hidden] = false if row[:hidden].nil?
      row[:user_deleted] = false if row[:user_deleted].nil?
      row[:wiki] = false if row[:wiki].nil?

      if row[:hidden]
        row[:hidden_reason_id] = ensure_valid_value(
          value: row[:hidden_reason_id],
          allowed_set: HIDDEN_REASONS,
          default_value: nil,
        )

        row[:hidden_at] ||= row[:updated_at] || row[:created_at]
      else
        row[:hidden_reason_id] = nil
        row[:hidden_at] = nil
      end

      row[:raw] = clean_raw(row[:raw], row[:post_type])
      if row[:raw] == BLANK_POST_RAW || row[:raw] == EMPTY_POST_RAW
        row[:word_count] = 0
      else
        row[:word_count] = row[:raw].scan(/[[:word:]]+/).size
      end

      # TODO(selase): Incomplete, temporary stand-in until we have a parser
      row[:cooked] = PrettyText.cook(row[:raw])
      row[:like_count] ||= 0
      row[:last_version_at] ||= row[:created_at]

      super
    end

    def clean_raw(raw, post_type)
      if raw
        raw.scrub!
        raw.strip!
      end

      return raw if raw.present?

      if post_type == SMALL_ACTION_TYPE || post_type == MODERATOR_ACTION_TYPE
        BLANK_POST_RAW
      else
        EMPTY_POST_RAW
      end
    end

    def load_existing_max_post_numbers
      @max_post_number_by_topic_id = Hash.new(0)

      topic_ids = @intermediate_db.query_splat <<~SQL, MappingType::TOPICS
        SELECT DISTINCT mapped_topic.discourse_id
          FROM posts
               JOIN mapped.ids mapped_topic
                 ON posts.topic_id = mapped_topic.original_id AND mapped_topic.type = ?
      SQL

      return if topic_ids.empty?

      DB
        .query(<<~SQL, topic_ids)
        SELECT topic_id, COALESCE(MAX(post_number), 0) AS max_post_number
        FROM posts
        WHERE topic_id IN (?)
        GROUP BY topic_id
      SQL
        .each { |row| @max_post_number_by_topic_id[row[:topic_id]] = row[:max_post_number] }
    end
  end
end
