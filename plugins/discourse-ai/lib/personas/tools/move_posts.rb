# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class MovePosts < Tool
        def self.signature
          {
            name: name,
            description: "Moves posts from one topic to another existing topic, or to a new topic.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the source topic containing the posts to move",
                type: "integer",
                required: true,
              },
              {
                name: "post_ids",
                description: "Array of post IDs to move",
                type: "array",
                item_type: "integer",
                required: true,
              },
              {
                name: "destination_topic_id",
                description:
                  "The ID of the existing topic to move posts to. Either this or new_title must be provided.",
                type: "integer",
              },
              {
                name: "new_title",
                description:
                  "Title for a new topic to create and move posts into. Either this or destination_topic_id must be provided.",
                type: "string",
              },
              {
                name: "category_id",
                description: "Category ID for the new topic (only used with new_title)",
                type: "integer",
              },
              {
                name: "reason",
                description: "Short explanation of why the posts are being moved",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "move_posts"
        end

        def invoke
          topic = Topic.find_by(id: parameters[:topic_id])
          return error_response(I18n.t("discourse_ai.ai_bot.move_posts.errors.not_found")) if !topic

          if !guardian.can_move_posts?(topic)
            return error_response(I18n.t("discourse_ai.ai_bot.move_posts.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.move_posts.errors.no_reason"))
          end

          post_ids = parameters[:post_ids]
          if post_ids.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.move_posts.errors.no_posts"))
          end

          destination_topic_id = parameters[:destination_topic_id]
          new_title = parameters[:new_title]

          if destination_topic_id.blank? && new_title.blank?
            return(error_response(I18n.t("discourse_ai.ai_bot.move_posts.errors.no_destination")))
          end

          opts = {}
          if destination_topic_id.present?
            opts[:destination_topic_id] = destination_topic_id
          else
            opts[:title] = new_title
            opts[:category_id] = parameters[:category_id] if parameters[:category_id].present?
          end

          destination_topic = topic.move_posts(acting_user, post_ids, opts)

          if destination_topic.present?
            {
              status: "success",
              message: I18n.t("discourse_ai.ai_bot.move_posts.success"),
              destination_topic_id: destination_topic.id,
            }
          else
            error_response(I18n.t("discourse_ai.ai_bot.move_posts.errors.move_failed"))
          end
        end

        def description_args
          { topic_id: parameters[:topic_id], post_ids: (parameters[:post_ids] || []).join(", ") }
        end
      end
    end
  end
end
