# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class DeleteTopic < Tool
        def self.signature
          {
            name: name,
            description: "Deletes or recovers a topic based on the deleted parameter.",
            parameters: [
              {
                name: "topic_id",
                description: "The ID of the topic",
                type: "integer",
                required: true,
              },
              {
                name: "deleted",
                description: "true to delete the topic, false to recover it",
                type: "boolean",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the topic is being deleted or recovered",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "delete_topic"
        end

        def invoke
          topic = Topic.with_deleted.find_by(id: parameters[:topic_id])
          if !topic
            return error_response(I18n.t("discourse_ai.ai_bot.delete_topic.errors.not_found"))
          end

          allowed =
            if !!parameters[:deleted]
              guardian.can_delete_topic?(topic)
            else
              guardian.can_recover_topic?(topic)
            end
          if !allowed
            return error_response(I18n.t("discourse_ai.ai_bot.delete_topic.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.delete_topic.errors.no_reason"))
          end

          first_post = Post.with_deleted.find_by(topic_id: topic.id, post_number: 1)
          if !first_post
            return error_response(I18n.t("discourse_ai.ai_bot.delete_topic.errors.not_found"))
          end

          if !!parameters[:deleted]
            PostDestroyer.new(acting_user, first_post, context: reason).destroy
          else
            PostDestroyer.new(acting_user, first_post, context: reason).recover
          end

          { status: "success", message: I18n.t("discourse_ai.ai_bot.delete_topic.success") }
        end

        def description_args
          { topic_id: parameters[:topic_id], deleted: parameters[:deleted] }
        end
      end
    end
  end
end
