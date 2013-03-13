module Jobs

  class FeatureTopicUsers < Jobs::Base

    def execute(args)
      topic = Topic.where(id: args[:topic_id]).first
      raise Discourse::InvalidParameters.new(:topic_id) unless topic.present?

      topic.feature_topic_users(args)
    end

  end

end
