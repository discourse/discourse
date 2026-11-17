# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class EditPost < Tool
        def self.signature
          {
            name: name,
            description:
              "Edits the content of a post, and optionally the topic title. Identify the post by post_id, or by topic_id and post_number when you only have its URL.",
            parameters: [
              {
                name: "post_id",
                description:
                  "The ID of the post to edit. Omit it when you identify the post by topic_id.",
                type: "integer",
              },
              {
                name: "topic_id",
                description:
                  "The ID of the topic containing the post, used instead of post_id. In a URL such as /t/some-title/123/4, the topic ID is 123.",
                type: "integer",
              },
              {
                name: "post_number",
                description:
                  "The number of the post within the topic, used with topic_id. In /t/some-title/123/4, the post number is 4. Defaults to 1, the first post, when the URL has no post number.",
                type: "integer",
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
          if (error = validation_error)
            return error
          end

          if !guardian.can_edit_post?(post)
            return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.not_allowed"))
          end

          raw = parameters[:raw]
          title = parameters[:title]
          edit_reason = parameters[:edit_reason].to_s.strip

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

        def validation_error
          targets_by_id = parameters[:post_id].present?
          targets_by_topic = parameters[:topic_id].present? || parameters[:post_number].present?
          if targets_by_id == targets_by_topic
            return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.invalid_target"))
          end
          return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.not_found")) if !post

          if parameters[:raw].blank? && parameters[:title].blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.nothing_to_edit"))
          end

          if parameters[:edit_reason].to_s.strip.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.edit_post.errors.no_reason"))
          end

          # Approval replay and DSA reporting read post_id from the stored parameters.
          self.parameters = parameters.except(:topic_id, :post_number).merge(post_id: post.id)
          nil
        end

        def description_args
          { post_id: parameters[:post_id] }
        end

        def approval_title
          return super if !previewable?(post)

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
          return [] if !previewable?(post)

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
          @post ||=
            if parameters[:post_id].present?
              Post.find_by(id: parameters[:post_id])
            else
              Post.find_by(
                topic_id: parameters[:topic_id],
                post_number: parameters[:post_number] || 1,
              )
            end
        end
      end
    end
  end
end
