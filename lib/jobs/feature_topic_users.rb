module Jobs

  class FeatureTopicUsers < Jobs::Base

    def execute(args)
      topic_id = args[:topic_id]
      raise Discourse::InvalidParameters.new(:topic_id) unless topic_id.present?

      topic = Topic.where(id: topic_id).first

      # there are 3 cases here
      # 1. topic was atomically nuked, this should be skipped
      # 2. topic was deleted, this should be skipped
      # 3. error an incorrect topic_id was sent

      unless topic.present?
        max_id = Topic.with_deleted.maximum(:id).to_i
        raise Discourse::InvalidParameters.new(:topic_id) if max_id < topic_id
        return
      end

      topic.feature_topic_users(args)
    end

  end

end
