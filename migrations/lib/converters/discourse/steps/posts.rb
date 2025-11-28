# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Posts < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM posts
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT posts.*,
              reply_to.id AS reply_to_post_id
        FROM posts
             LEFT JOIN posts reply_to ON reply_to.topic_id = posts.topic_id
               AND reply_to.post_number = posts.reply_to_post_number
        ORDER BY posts.topic_id, posts.post_number
      SQL
    end

    def process_item(item)
      # TODO(selase): Implement raw parsinig and conversion
      IntermediateDB::Post.create(
        original_id: item[:id],
        topic_id: item[:topic_id],
        user_id: item[:user_id],
        post_number: item[:post_number],
        raw: item[:raw],
        original_raw: item[:raw],
        created_at: item[:created_at],
        deleted_at: item[:deleted_at],
        post_type: resolve_enum(Enums::PostType, item[:post_type], Enums::PostType::REGULAR),
        sort_order: item[:sort_order],
        reply_to_post_id: item[:reply_to_post_id],
        reply_to_user_id: item[:reply_to_user_id],
        last_editor_id: item[:last_editor_id],
        hidden: item[:hidden],
        hidden_at: item[:hidden_at],
        hidden_reason_id: resolve_enum(Enums::PostHiddenReason, item[:hidden_reason_id]),
        user_deleted: item[:user_deleted],
        deleted_by_id: item[:deleted_by_id],
        wiki: item[:wiki],
        action_code: item[:action_code],
        locked_by_id: item[:locked_by_id],
        like_count: item[:like_count],
      )
    end

    private

    def resolve_enum(enum_module, value, fallback = nil)
      enum_module.valid?(value) ? value : fallback
    end
  end
end
