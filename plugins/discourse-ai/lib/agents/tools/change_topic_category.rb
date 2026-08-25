# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class ChangeTopicCategory < Tool
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
          "change_topic_category"
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
          perform_move
        end

        def validation_error
          if topic.blank? || topic.first_post.blank?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.change_topic_category.errors.not_found"))
            )
          end

          if category.blank?
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.change_topic_category.errors.category_not_found"),
              )
            )
          end

          if reason.blank?
            return(
              error_response(I18n.t("discourse_ai.ai_bot.change_topic_category.errors.no_reason"))
            )
          end

          nil
        end

        def description_args
          { topic_id: parameters[:topic_id], category_id: parameters[:category_id] }
        end

        private

        def topic
          @topic ||= Topic.find_by(id: parameters[:topic_id])
        end

        def category
          @category ||= Category.find_by(id: parameters[:category_id])
        end

        def perform_move
          if !guardian.can_edit_topic?(topic)
            return(
              error_response(I18n.t("discourse_ai.ai_bot.change_topic_category.errors.not_allowed"))
            )
          end

          revisor = PostRevisor.new(topic.first_post, topic)
          result =
            revisor.revise!(
              guardian.user,
              { category_id: category.id }.tap do |f|
                f[:edit_reason] = reason if !!parameters[:public_edit_reason]
              end,
            )

          if result
            {
              status: "success",
              message: I18n.t("discourse_ai.ai_bot.change_topic_category.success"),
            }
          else
            error_response(
              I18n.t("discourse_ai.ai_bot.change_topic_category.errors.revision_failed"),
            )
          end
        end
      end
    end
  end
end
