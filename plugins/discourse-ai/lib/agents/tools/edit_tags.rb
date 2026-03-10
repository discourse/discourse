# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class EditTags < Tool
        def self.signature
          {
            name: name,
            description: "Adds tags to a topic. By default appends to existing tags.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic",
                type: "integer",
                required: true,
              },
              {
                name: "tags",
                description: "Array of tag names to add to the topic",
                type: "array",
                item_type: "string",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the tags are being changed",
                type: "string",
                required: true,
              },
              {
                name: "replace",
                description:
                  "When true, replaces all existing tags with the given list. Defaults to false (append).",
                type: "boolean",
              },
              {
                name: "public_edit_reason",
                description: "Whether the reason should be visible in the post's revision history",
                type: "boolean",
              },
            ],
          }
        end

        def self.name
          "edit_tags"
        end

        def invoke
          if !SiteSetting.tagging_enabled
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tags.errors.tagging_disabled"))
          end

          topic = Topic.find_by(id: parameters[:topic_id])
          return error_response(I18n.t("discourse_ai.ai_bot.edit_tags.errors.not_found")) if !topic

          if !guardian.can_edit_tags?(topic)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tags.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tags.errors.no_reason"))
          end

          tag_names = parameters[:tags] || []
          tag_names = (topic.tags.pluck(:name) + tag_names).uniq if !parameters[:replace]

          fields = { tags: tag_names }
          fields[:edit_reason] = reason if !!parameters[:public_edit_reason]

          first_post = topic.first_post
          if !first_post
            return error_response(I18n.t("discourse_ai.ai_bot.edit_tags.errors.not_found"))
          end

          revisor = PostRevisor.new(first_post, topic)
          result = revisor.revise!(acting_user, fields)

          if result
            { status: "success", message: I18n.t("discourse_ai.ai_bot.edit_tags.success") }
          else
            error_response(topic.errors.full_messages.join(", "))
          end
        end

        def description_args
          { topic_id: parameters[:topic_id], tags: (parameters[:tags] || []).join(", ") }
        end
      end
    end
  end
end
