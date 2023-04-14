# frozen_string_literal: true

module Jobs
  class RemoveBanner < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]

      return unless topic_id.present?

      topic = Topic.find_by(id: topic_id)
      topic.remove_banner!(Discourse.system_user) if topic.present?
    end
  end
end
