# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class CloseTopic < Tool
        def self.signature
          {
            name: name,
            description: "Closes or opens a topic based on the closed parameter.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic",
                type: "integer",
                required: true,
              },
              {
                name: "closed",
                description: "true to close the topic, false to open it",
                type: "boolean",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the topic is being closed or opened",
                type: "string",
                required: true,
              },
              {
                name: "public_reason",
                description:
                  "Whether the reason should be posted as a small action post visible to topic participants",
                type: "boolean",
              },
            ],
          }
        end

        def self.name
          "close_topic"
        end

        def invoke
          topic = Topic.find_by(id: parameters[:topic_id])
          if !topic
            return error_response(I18n.t("discourse_ai.ai_bot.close_topic.errors.not_found"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.close_topic.errors.no_reason"))
          end

          closed = !!parameters[:closed]

          opts = {}
          opts[:message] = reason if !!parameters[:public_reason]
          TopicStatusUpdater.new(topic, acting_user).update!("closed", closed, opts)

          { status: "success", message: I18n.t("discourse_ai.ai_bot.close_topic.success") }
        end

        def description_args
          { topic_id: parameters[:topic_id], closed: parameters[:closed] }
        end

        private

        def reason
          parameters[:reason].to_s.strip
        end

        def error_response(message)
          { status: "error", error: message }
        end
      end
    end
  end
end
