# frozen_string_literal: true

module Jobs

  class FeatureTopicUsers < ::Jobs::Base

    def execute(args)
      topic_id = args[:topic_id]
      raise Discourse::InvalidParameters.new(:topic_id) unless topic_id.present?

      topic = Topic.find_by(id: topic_id)

      # Topic may be hard deleted due to spam, no point complaining
      # we would have to look at the topics table id sequence to find cases
      # where this was called with an invalid id, no point really
      return unless topic.present?

      topic.feature_topic_users(args)
    end

  end

end
