# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnpinTopic
      class V1 < NodeType
        include TopicPinning

        description TopicPinning.description(name: "action:unpin_topic", icon: "thumbtack")

        private

        def change(_exec_ctx, topic, actor, _item_index)
          ensure_can_pin!(topic, actor, globally: false)
          pinned = topic.pinned_at.present?
          topic.update_status("pinned", false, actor) if pinned
          topic.reload

          { topic: serialize_topic(topic, guardian: actor.guardian), changed: pinned }
        end
      end
    end
  end
end
