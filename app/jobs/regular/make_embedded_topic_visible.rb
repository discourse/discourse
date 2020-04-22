# frozen_string_literal: true

module Jobs
  class MakeEmbeddedTopicVisible < ::Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?

      if topic = Topic.find_by(id: args[:topic_id])
        topic.update_status('visible', true, topic.user)
      end
    end

  end
end
