# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class EditCategory < Tool
        def self.signature
          {
            name: name,
            description: "Moves a topic to a different category.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic to move",
                type: "integer",
                required: true,
              },
              {
                name: "category_id",
                description: "The ID of the target category",
                type: "integer",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the topic is being moved",
                type: "string",
                required: true,
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
          "edit_category"
        end

        def invoke
          topic = Topic.find_by(id: parameters[:topic_id])
          if !topic
            return error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.not_found"))
          end

          if !guardian.can_edit_topic?(topic)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.not_allowed"))
          end

          category = Category.find_by(id: parameters[:category_id])
          if !category
            return(
              error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.category_not_found"))
            )
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.no_reason"))
          end

          first_post = topic.first_post
          if !first_post
            return error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.not_found"))
          end

          revisor = PostRevisor.new(first_post, topic)
          result =
            revisor.revise!(
              acting_user,
              { category_id: category.id }.tap do |f|
                f[:edit_reason] = reason if !!parameters[:public_edit_reason]
              end,
            )

          if result
            { status: "success", message: I18n.t("discourse_ai.ai_bot.edit_category.success") }
          else
            error_response(I18n.t("discourse_ai.ai_bot.edit_category.errors.revision_failed"))
          end
        end

        def description_args
          { topic_id: parameters[:topic_id], category_id: parameters[:category_id] }
        end
      end
    end
  end
end
