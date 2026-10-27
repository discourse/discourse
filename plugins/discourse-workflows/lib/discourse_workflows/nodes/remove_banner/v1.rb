# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RemoveBanner
      class V1 < NodeType
        include TopicPinning

        description TopicPinning.description(name: "action:remove_banner", icon: "bullhorn")

        private

        def change(_exec_ctx, topic, actor, _item_index)
          ensure_can_banner!(topic, actor)
          bannered = topic.archetype == ::Archetype.banner
          topic.remove_banner!(actor) if bannered
          topic.reload

          { topic: serialize_topic(topic, guardian: actor.guardian), changed: bannered }
        end
      end
    end
  end
end
