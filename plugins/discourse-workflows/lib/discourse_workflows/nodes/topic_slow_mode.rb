# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Set and clear slow mode share the core slow mode service and how its failures become node errors.
    module TopicSlowMode
      include TopicChangeAction

      I18N_SCOPE = "topic_slow_mode"
      # Shared with Slow mode set, which reports the same settings.
      OUTPUT = {
        "slow_mode_seconds" => {
          "type" => "integer",
        },
        "slow_mode_enabled_until" => {
          "type" => %w[string null],
          "format" => "date-time",
        },
      }.freeze

      def self.description(name:, icon:, properties: {}, output: {})
        TopicChangeAction.description(
          name:,
          icon:,
          color: "light-blue",
          i18n_scope: I18N_SCOPE,
          changed: "False when the topic already had this slow mode",
          properties:,
          output:,
        )
      end

      private

      def update_slow_mode(topic, actor, item_index, seconds:, enabled_until: nil)
        ::Topic::UpdateSlowMode.call(
          guardian: actor.guardian,
          params: {
            topic_id: topic.id,
            seconds:,
            enabled_until:,
          },
        ) do
          on_success { topic.reload }
          on_failed_policy(:can_update_slow_mode) do
            slow_mode_error!(
              "not_allowed",
              item_index,
              username: actor.username,
              topic_id: topic.id,
            )
          end
          on_failed_contract do |contract|
            slow_mode_error!(
              "invalid",
              item_index,
              errors: contract.errors.full_messages.join(", "),
            )
          end
          on_failure { slow_mode_error!("failed", item_index, topic_id: topic.id) }
        end
      end

      def slow_mode_error!(key, item_index, **args)
        raise_node_error!(
          I18n.t("discourse_workflows.errors.topic_slow_mode.#{key}", **args),
          item_index:,
        )
      end
    end
  end
end
