# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicUnbannered
      class V1 < NodeType
        include TopicBannerTrigger

        description(
          TopicBannerTrigger.description(
            name: "trigger:topic_unbannered",
            event: :topic_unbannered,
          ),
        )
      end
    end
  end
end
