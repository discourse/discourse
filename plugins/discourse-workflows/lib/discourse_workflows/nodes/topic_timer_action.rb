# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Set and clear topic timer share the topic's timer types and the topics controller's permission checks.
    # Each node defines #change_timer, returning the timer and whether it changed.
    module TopicTimerAction
      include TopicChangeAction

      I18N_SCOPE = "topic_timer_action"
      TIMER_TYPES = ::TopicTimer.public_types.keys.map(&:to_s).freeze

      def self.description(name:, properties:, timer_schema:, changed_description:)
        TopicChangeAction.description(
          name:,
          icon: "clock",
          color: "orange",
          i18n_scope: I18N_SCOPE,
          changed: changed_description,
          properties: {
            timer_type: {
              type: :options,
              required: true,
              default: "close",
              options: TIMER_TYPES,
            },
            **properties,
          },
          output: {
            "timer" => timer_schema,
          },
        )
      end

      private

      def change(exec_ctx, topic, actor, item_index)
        type_id = timer_type_id(exec_ctx, item_index)
        ensure_can_change_timer!(topic, actor, type_id)

        timer, changed = change_timer(exec_ctx, topic, actor, type_id, item_index)
        topic.reload

        {
          topic: serialize_topic(topic, guardian: actor.guardian),
          timer: timer && serialize_timer(timer),
          changed:,
        }
      end

      def timer_type_id(exec_ctx, item_index)
        ::TopicTimer.public_types[
          option(exec_ctx, "timer_type", TIMER_TYPES, "close", item_index).to_sym
        ]
      end

      def option(exec_ctx, name, allowed, default, item_index)
        value = exec_ctx.get_node_parameter(name, item_index, default:).to_s
        return value if allowed.include?(value)

        node_error!("invalid_#{name}", item_index, name.to_sym => value)
      end

      def node_error!(key, item_index, **args)
        raise_node_error!(
          I18n.t("discourse_workflows.errors.topic_timer.#{key}", **args),
          item_index:,
        )
      end

      def ensure_can_change_timer!(topic, actor, type_id)
        guardian = actor.guardian
        guardian.ensure_can_set_topic_timer!(topic)
        guardian.ensure_can_delete!(topic) if ::TopicTimer.destructive_types.value?(type_id)
      end
    end
  end
end
