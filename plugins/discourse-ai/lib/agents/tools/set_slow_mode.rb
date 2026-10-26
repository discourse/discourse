# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SetSlowMode < Tool
        def self.signature
          {
            name: name,
            description:
              "Enables or disables slow mode on a topic. Slow mode limits how frequently users can post.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic",
                type: "integer",
                required: true,
              },
              {
                name: "slow_mode_seconds",
                description: "Number of seconds between posts. Set to 0 to disable slow mode.",
                type: "integer",
                required: true,
              },
              {
                name: "duration_hours",
                description:
                  "Number of hours until slow mode automatically expires. Omit for no expiration.",
                type: "integer",
              },
              {
                name: "reason",
                description: "Short explanation of why slow mode is being set",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "set_slow_mode"
        end

        def self.requires_approval?
          true
        end

        def invoke
          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.set_slow_mode.errors.no_reason"))
          end

          Topic::UpdateSlowMode.call(
            guardian:,
            params: {
              topic_id: parameters[:topic_id],
              seconds: parameters[:slow_mode_seconds],
              enabled_until: parameters[:duration_hours],
            },
          ) do
            on_success do
              { status: "success", message: I18n.t("discourse_ai.ai_bot.set_slow_mode.success") }
            end
            on_failed_contract do |contract|
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.set_slow_mode.errors.invalid",
                  errors: contract.errors.full_messages.join(", "),
                ),
              )
            end
            on_model_not_found(:topic) do
              error_response(I18n.t("discourse_ai.ai_bot.set_slow_mode.errors.not_found"))
            end
            on_failed_policy(:can_update_slow_mode) do
              error_response(I18n.t("discourse_ai.ai_bot.set_slow_mode.errors.not_allowed"))
            end
          end
        end

        def description_args
          { topic_id: parameters[:topic_id], slow_mode_seconds: parameters[:slow_mode_seconds] }
        end
      end
    end
  end
end
