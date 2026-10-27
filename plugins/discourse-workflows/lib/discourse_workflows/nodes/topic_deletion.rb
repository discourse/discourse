# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Both directions go through the topic's first post like its delete and recover buttons. Each node
    # defines DELETED and #change_deletion.
    module TopicDeletion
      include TopicChangeAction

      I18N_SCOPE = "topic_deletion"

      def self.description(name:, icon:, color:)
        TopicChangeAction.description(
          name:,
          icon:,
          color:,
          i18n_scope: I18N_SCOPE,
          changed: "False when the topic was already in that state",
        )
      end

      private

      def find_topic(topic_id)
        ::Topic.with_deleted.find(topic_id)
      end

      def change(exec_ctx, topic, actor, _item_index)
        guardian = actor.guardian
        was_deleted = topic.trashed?

        if was_deleted == self.class::DELETED
          guardian.ensure_can_see!(topic)
          return { topic: serialize_topic(topic, guardian:), changed: false }
        end

        change_deletion(exec_ctx, topic, actor)
        topic.reload

        { topic: serialize_topic(topic, guardian:), changed: topic.trashed? != was_deleted }
      end
    end
  end
end
