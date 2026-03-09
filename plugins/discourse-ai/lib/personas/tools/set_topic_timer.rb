# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class SetTopicTimer < Tool
        TIMER_TYPES = %w[close open delete silent_close bump].freeze

        def self.signature
          {
            name: name,
            description:
              "Sets or removes a timer on a topic. Timers can close, open, delete, silently close, or bump a topic after a specified duration.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic",
                type: "integer",
                required: true,
              },
              {
                name: "timer_type",
                description: "The type of timer: close, open, delete, silent_close, or bump",
                type: "string",
                required: true,
              },
              {
                name: "duration_hours",
                description:
                  "Number of hours from now until the timer fires. Set to null to remove an existing timer.",
                type: "integer",
              },
              {
                name: "reason",
                description: "Short explanation of why the timer is being set",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "set_topic_timer"
        end

        def invoke
          topic = Topic.find_by(id: parameters[:topic_id])
          if !topic
            return error_response(I18n.t("discourse_ai.ai_bot.set_topic_timer.errors.not_found"))
          end

          if !guardian.can_moderate_topic?(topic)
            return(error_response(I18n.t("discourse_ai.ai_bot.set_topic_timer.errors.not_allowed")))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.set_topic_timer.errors.no_reason"))
          end

          timer_type = parameters[:timer_type].to_s
          if !TIMER_TYPES.include?(timer_type)
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.set_topic_timer.errors.invalid_timer_type"),
              )
            )
          end

          duration_hours = parameters[:duration_hours]

          topic.set_or_create_timer(
            TopicTimer.types[timer_type.to_sym],
            duration_hours,
            by_user: acting_user,
          )

          { status: "success", message: I18n.t("discourse_ai.ai_bot.set_topic_timer.success") }
        end

        def description_args
          {
            topic_id: parameters[:topic_id],
            timer_type: parameters[:timer_type],
            duration_hours: parameters[:duration_hours],
          }
        end
      end
    end
  end
end
