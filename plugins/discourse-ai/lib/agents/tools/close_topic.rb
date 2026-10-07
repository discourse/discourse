# frozen_string_literal: true

module DiscourseAi
  module Agents
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

        def self.requires_approval?
          true
        end

        def invoke
          topic = Topic.find_by(id: parameters[:topic_id])
          if !topic
            return error_response(I18n.t("discourse_ai.ai_bot.close_topic.errors.not_found"))
          end

          if !guardian.can_close_topic?(topic)
            return error_response(I18n.t("discourse_ai.ai_bot.close_topic.errors.not_allowed"))
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

        def approval_title
          return super if topic.blank?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.topic_title",
            topic: DiscourseAi::AiBot::ChatToolApproval.format_topic(topic),
          )
        end

        def approval_changes
          return [] if topic.blank?

          [
            {
              label: I18n.t("discourse_ai.ai_bot.chat_tool_approval.topic_status_label"),
              before:
                I18n.t(
                  "discourse_ai.ai_bot.chat_tool_approval.topic_states.#{topic.closed ? "closed" : "open"}",
                ),
              after:
                I18n.t(
                  "discourse_ai.ai_bot.chat_tool_approval.topic_states.#{parameters[:closed] ? "closed" : "open"}",
                ),
            },
          ]
        end

        def approval_parameters
          []
        end

        private

        def topic
          @topic ||= Topic.find_by(id: parameters[:topic_id])
        end
      end
    end
  end
end
