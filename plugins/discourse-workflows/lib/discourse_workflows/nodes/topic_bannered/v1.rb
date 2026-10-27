# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicBannered
      class V1 < NodeType
        include TopicBannerTrigger

        description(
          TopicBannerTrigger.description(name: "trigger:topic_bannered", event: :topic_bannered),
        )
      end
    end
  end
end
