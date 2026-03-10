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

        def invoke
          topic = Topic.find_by(id: parameters[:topic_id])
          if !topic
            return error_response(I18n.t("discourse_ai.ai_bot.set_slow_mode.errors.not_found"))
          end

          if !guardian.can_moderate_topic?(topic)
            return error_response(I18n.t("discourse_ai.ai_bot.set_slow_mode.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.set_slow_mode.errors.no_reason"))
          end

          slow_mode_seconds = parameters[:slow_mode_seconds].to_i
          topic.update!(slow_mode_seconds: slow_mode_seconds)

          enabled_until =
            if slow_mode_seconds > 0 && parameters[:duration_hours]
              parameters[:duration_hours].to_i.hours.from_now
            end

          topic.set_or_create_timer(
            TopicTimer.types[:clear_slow_mode],
            enabled_until,
            by_user: acting_user,
          )

          { status: "success", message: I18n.t("discourse_ai.ai_bot.set_slow_mode.success") }
        end

        def description_args
          { topic_id: parameters[:topic_id], slow_mode_seconds: parameters[:slow_mode_seconds] }
        end
      end
    end
  end
end
