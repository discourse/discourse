# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class EditPost < Tool
        def self.signature
          {
            name: name,
            description: "Edits the content of a post, and optionally the topic title.",
            parameters: [
              {
                name: "post_id",
                description: "The ID of the post to edit",
                type: "integer",
                required: true,
              },
              { name: "raw", description: "The new raw content for the post", type: "string" },
              {
                name: "title",
                description: "The new title for the topic (only applies to the first post)",
                type: "string",
              },
              {
                name: "edit_reason",
                description: "Short explanation of what was changed",
                type: "string",
                required: true,
              },
              {
                name: "public_edit_reason",
                description:
                  "Whether the edit reason should be visible in the post's revision history",
                type: "boolean",
              },
            ],
          }
        end

        def self.name
          "edit_post"
        end

        def self.requires_approval?
          true
        end

        def invoke
          post = Post.find_by(id: parameters[:post_id])
          return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.not_found")) if !post

          if !guardian.can_edit_post?(post)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.not_allowed"))
          end

          raw = parameters[:raw]
          title = parameters[:title]
          edit_reason = parameters[:edit_reason].to_s.strip

          if raw.blank? && title.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.nothing_to_edit"))
          end

          if edit_reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.no_reason"))
          end

          fields = {}
          fields[:edit_reason] = edit_reason if !!parameters[:public_edit_reason]
          fields[:raw] = raw if raw.present?
          fields[:title] = title if title.present?

          revisor = PostRevisor.new(post, post.topic)
          result = revisor.revise!(acting_user, fields)

          if result
            { status: "success", message: I18n.t("discourse_ai.ai_bot.edit_post.success") }
          else
            error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.revision_failed"))
          end
        end

        def description_args
          { post_id: parameters[:post_id] }
        end

        def approval_title
          return super if post.blank?

          label =
            I18n.t(
              "discourse_ai.ai_bot.chat_tool_approval.post_reference",
              topic: post.topic.title,
              number: post.post_number,
            )
          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.post_title",
            post: DiscourseAi::AiBot::ChatToolApproval.format_link(label, post.url),
          )
        end

        def approval_changes
          return [] if post.blank?

          changes = []
          if parameters[:raw].present?
            changes << {
              label: I18n.t("discourse_ai.ai_bot.chat_tool_approval.post_content_label"),
              before: post.raw,
              after: parameters[:raw],
            }
          end
          if parameters[:title].present? && post.is_first_post?
            changes << {
              label: I18n.t("discourse_ai.ai_bot.chat_tool_approval.post_topic_title_label"),
              before: post.topic.title,
              after: parameters[:title],
            }
          end
          changes
        end

        def approval_parameters
          []
        end

        private

        def post
          @post ||= Post.find_by(id: parameters[:post_id])
        end
      end
    end
  end
end
