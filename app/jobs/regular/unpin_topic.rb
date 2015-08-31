module Jobs

  class UnpinTopic < Jobs::Base

    def execute(args)
      topic_id = args[:topic_id]

      raise Discourse::InvalidParameters.new(:topic_id) unless topic_id.present?

      topic = Topic.find_by(id: topic_id)
      topic.update_pinned(false) if topic.present?
    end

  end

end
