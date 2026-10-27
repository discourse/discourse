# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Permission checks and expiry parsing shared by the pin and banner actions.
    module TopicPinning
      include TopicChangeAction

      # Reuses the labels of the Topic pinning node they replace.
      I18N_SCOPE = "topic_pin"

      TIMEZONE_PROPERTY =
        NodeType.timezone_property(none: "discourse_workflows.topic_pin.timezone_none").freeze

      def self.description(name:, icon:, properties: {}, output: {})
        TopicChangeAction.description(
          name:,
          icon:,
          color: "pink",
          i18n_scope: I18N_SCOPE,
          changed: "False when the topic was already in this state",
          properties:,
          output:,
        )
      end

      private

      def ensure_can_pin!(topic, actor, globally:)
        guardian = actor.guardian
        allowed = globally ? guardian.can_moderate?(topic) : guardian.can_pin_unpin_topic?(topic)
        return if allowed

        denied!(globally ? "pin_globally_not_allowed" : "pin_not_allowed", actor, topic)
      end

      def ensure_can_banner!(topic, actor)
        return if actor.guardian.can_banner_topic?(topic)

        if topic.private_message?
          raise_node_error!(I18n.t("discourse_workflows.errors.topic_pin.banner_private_message"))
        elsif topic.category&.read_restricted?
          raise_node_error!(
            I18n.t("discourse_workflows.errors.topic_pin.banner_restricted_category"),
          )
        else
          denied!("banner_not_allowed", actor, topic)
        end
      end

      def denied!(key, actor, topic)
        raise_node_error!(
          I18n.t(
            "discourse_workflows.errors.topic_pin.#{key}",
            username: actor.username,
            topic_id: topic.id,
          ),
        )
      end

      def timestamp(exec_ctx, config, prefix, item_index)
        parse_time_in_timezone(
          exec_ctx,
          config["#{prefix}_until"],
          item_index:,
          field: "#{prefix}_until",
          error_key: "discourse_workflows.errors.topic_pin.invalid_timestamp",
        )&.iso8601
      end
    end
  end
end
