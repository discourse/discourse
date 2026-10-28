# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Both directions share the topic converter, its permission and how a failed conversion becomes a
    # node error. Each node defines TO_PRIVATE_MESSAGE and #convert.
    module TopicConversion
      include TopicChangeAction

      I18N_SCOPE = "topic_conversion"

      def self.description(name:, icon:, properties: {})
        TopicChangeAction.description(
          name:,
          icon:,
          color: "light-blue",
          i18n_scope: I18N_SCOPE,
          changed: "False when the topic was already in this form",
          properties:,
          allow_anonymous: false,
        )
      end

      private

      def change(exec_ctx, topic, actor, item_index)
        actor.guardian.ensure_can_convert_topic!(topic)

        target = self.class::TO_PRIVATE_MESSAGE
        if topic.private_message? == target
          return { topic: serialize_topic(topic, guardian: actor.guardian), changed: false }
        end

        convert(exec_ctx, topic, actor, item_index)
        errors = topic.errors.full_messages
        topic.reload

        if topic.private_message? != target
          failed_key = target ? "to_personal_message_failed" : "to_public_topic_failed"
          raise_node_error!(
            errors.join(", ").presence || conversion_error(failed_key, topic),
            item_index:,
          )
        end

        { topic: serialize_topic(topic, guardian: actor.guardian), changed: true }
      end

      def conversion_error(key, topic)
        I18n.t("discourse_workflows.errors.topic_conversion.#{key}", topic_id: topic.id)
      end
    end
  end
end
