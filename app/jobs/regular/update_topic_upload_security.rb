# frozen_string_literal: true

module Jobs

  class UpdateTopicUploadSecurity < ::Jobs::Base

    def execute(args)
      topic = Topic.find_by(id: args[:topic_id])
      if topic.blank?
        Rails.logger.info("Could not find topic #{args[:topic_id]} for topic upload security updater.")
        return
      end
      TopicUploadSecurityManager.new(topic).run
    end
  end
end
