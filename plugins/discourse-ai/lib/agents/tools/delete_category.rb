# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class DeleteCategory < Tool
        def self.signature
          {
            name: name,
            description:
              "Permanently deletes an empty category. Categories that still contain topics or subcategories cannot be deleted; the result explains what is left and links to the category's settings so the administrator can handle it.",
            parameters: [
              {
                name: "category_id",
                description: "The ID of the category to delete",
                type: "integer",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the category is being deleted",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "delete_category"
        end

        def self.requires_approval?
          true
        end

        def self.attribute_to_approver?
          true
        end

        def invoke
          if (error = validation_error)
            return error
          end
          perform_delete
        end

        def validation_error
          if category.blank? || !guardian.can_see_category?(category)
            return error_response(I18n.t("discourse_ai.ai_bot.delete_category.errors.not_found"))
          end

          if !guardian.can_edit_category?(category)
            return error_response(I18n.t("discourse_ai.ai_bot.delete_category.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.delete_category.errors.no_reason"))
          end

          if (blocker = deletion_blocker)
            return error_response(blocker)
          end

          nil
        end

        def description_args
          {
            category_name:
              (
                if category
                  DiscourseAi::AiBot::ChatToolApproval.format_category(category)
                else
                  parameters[:category_id]
                end
              ),
          }
        end

        def approval_title
          return super if !previewable?(category)

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.delete_category_title",
            category: DiscourseAi::AiBot::ChatToolApproval.format_category(category),
          )
        end

        def approval_details
          return super if !previewable?(category)

          I18n.t("discourse_ai.ai_bot.chat_tool_approval.delete_category_details")
        end

        def approval_question
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.delete_category_question")
        end

        def approval_parameters
          []
        end

        private

        def category
          @category ||= Category.find_by(id: parameters[:category_id])
        end

        def settings_url
          "#{Discourse.base_url_no_prefix}#{category.slug_url_without_id}/edit/general"
        end

        # `topic_count` is refreshed periodically, so live topics are counted
        # directly to avoid deleting a category that only looks empty.
        def topic_count
          Topic.where(category_id: category.id).where.not(id: category.topic_id).count
        end

        def deletion_blocker
          if category.uncategorized?
            return I18n.t("discourse_ai.ai_bot.delete_category.errors.uncategorized")
          end

          if category.has_children?
            return(
              I18n.t(
                "discourse_ai.ai_bot.delete_category.errors.has_subcategories",
                name: category.name,
                url: settings_url,
              )
            )
          end

          count = topic_count
          if count > 0 || !guardian.can_delete_category?(category)
            return(
              I18n.t(
                "discourse_ai.ai_bot.delete_category.errors.has_topics",
                count: [count, category.topic_count].max,
                name: category.name,
                url: settings_url,
              )
            )
          end

          nil
        end

        def perform_delete
          name = category.name
          CategoryDestroyer.destroy(guardian, category)

          {
            status: "success",
            message: I18n.t("discourse_ai.ai_bot.delete_category.success", name:),
          }
        rescue Discourse::InvalidAccess
          error_response(
            deletion_blocker || I18n.t("discourse_ai.ai_bot.delete_category.errors.not_allowed"),
          )
        end
      end
    end
  end
end
