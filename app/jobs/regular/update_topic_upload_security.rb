# frozen_string_literal: true

module Jobs

  class UpdateTopicUploadSecurity < ::Jobs::Base

    def execute(args)
      TopicUploadSecurityManager.new(Topic.find(args[:topic_id])).run
    end
  end
end
