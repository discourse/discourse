# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Close/reopen, archive/unarchive and unlist/list only differ by the status they set and the permission
    # they check, defined by each node as STATUS, ENABLED, PERMISSION and STATUS_OPTIONS.
    module TopicStatusAction
      include TopicChangeAction

      I18N_SCOPE = "topic_status_action"
      STATUS_OPTIONS = {}.freeze

      def self.description(name:, icon:)
        TopicChangeAction.description(
          name:,
          icon:,
          color: "light-blue",
          i18n_scope: I18N_SCOPE,
          changed: "False when the topic already had this status",
        )
      end

      private

      def change(_exec_ctx, topic, actor, _item_index)
        actor.guardian.public_send(self.class::PERMISSION, topic)

        status = self.class::STATUS
        before = topic.public_send(status)
        TopicStatusUpdater.new(topic, actor).update!(
          status,
          self.class::ENABLED,
          self.class::STATUS_OPTIONS,
        )
        topic.reload

        {
          topic: serialize_topic(topic, guardian: actor.guardian),
          changed: topic.public_send(status) != before,
        }
      end
    end
  end
end
