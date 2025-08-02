# frozen_string_literal: true

module Jobs
  class UnpinTopic < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]

      return if topic_id.blank?

      topic = Topic.find_by(id: topic_id)
      topic.update_pinned(false) if topic.present?
    end
  end
end
