# frozen_string_literal: true

module DiscourseAi
  class AiApiAuditLogCleaner
    def self.delete_for_post(post_id)
      AiApiAuditLog.where(post_id:).delete_all
    end

    def self.delete_for_topic(topic_id)
      AiApiAuditLog.where(topic_id:).delete_all
    end

    def self.delete_for_user(user_id)
      AiApiAuditLog.where(user_id:).delete_all
    end

    # logs reference the content they were generated against, so when a user's
    # posts and topics are removed alongside the account we clear those too.
    # with_deleted covers content already soft-deleted (e.g. "delete all posts")
    # before the account itself is deleted.
    def self.delete_for_user_content(user)
      AiApiAuditLog.where(post_id: Post.with_deleted.where(user_id: user.id).select(:id)).delete_all
      AiApiAuditLog.where(
        topic_id: Topic.with_deleted.where(user_id: user.id).select(:id),
      ).delete_all
    end
  end
end
