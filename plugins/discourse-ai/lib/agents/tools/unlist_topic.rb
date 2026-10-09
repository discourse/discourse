# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class UnlistTopic < Tool
        def self.signature
          {
            name: name,
            description: "Unlists or lists a topic based on the unlisted parameter.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic",
                type: "integer",
                required: true,
              },
              {
                name: "unlisted",
                description: "true to unlist the topic, false to list it",
                type: "boolean",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the topic is being unlisted or listed",
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
          "unlist_topic"
        end

        def self.requires_approval?
          true
        end

        def invoke
          topic = Topic.find_by(id: parameters[:topic_id])
          if !topic
            return error_response(I18n.t("discourse_ai.ai_bot.unlist_topic.errors.not_found"))
          end

          if !guardian.can_toggle_topic_visibility?(topic)
            return error_response(I18n.t("discourse_ai.ai_bot.unlist_topic.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.unlist_topic.errors.no_reason"))
          end

          unlisted = !!parameters[:unlisted]

          opts = {}
          opts[:message] = reason if !!parameters[:public_reason]
          TopicStatusUpdater.new(topic, acting_user).update!("visible", !unlisted, opts)
          if unlisted && !topic.reload.visible? && topic.first_post
            @restrictions << Reviewable::Restriction.new(kind: :demoted, target: topic.first_post)
          end

          { status: "success", message: I18n.t("discourse_ai.ai_bot.unlist_topic.success") }
        end

        def description_args
          { topic_id: parameters[:topic_id], unlisted: parameters[:unlisted] }
        end

        def approval_title
          return super if !previewable?(topic)

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.topic_title",
            topic: DiscourseAi::AiBot::ChatToolApproval.format_topic(topic),
          )
        end

        def approval_changes
          return [] if !previewable?(topic)

          [
            {
              label: I18n.t("discourse_ai.ai_bot.chat_tool_approval.topic_visibility_label"),
              before:
                I18n.t(
                  "discourse_ai.ai_bot.chat_tool_approval.topic_states.#{!topic.visible ? "unlisted" : "listed"}",
                ),
              after:
                I18n.t(
                  "discourse_ai.ai_bot.chat_tool_approval.topic_states.#{parameters[:unlisted] ? "unlisted" : "listed"}",
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
