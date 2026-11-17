# frozen_string_literal: true

module Jobs
  module Boards
    class SyncTopic < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.boards_enabled?

        topic_id = args[:topic_id]
        return if topic_id.blank?

        topic = Topic.find_by(id: topic_id)
        return if topic.blank?

        ::Boards::TopicSync.sync_topic(topic)
      end
    end
  end
end
