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
  end
end
