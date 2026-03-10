# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class MarkAsSolved < Tool
        def self.signature
          {
            name: name,
            description:
              "Marks or unmarks a post as the accepted solution for its topic based on the solved parameter.",
            parameters: [
              {
                name: "post_id",
                description: "The ID of the post to mark or unmark as the solution",
                type: "integer",
                required: true,
              },
              {
                name: "solved",
                description: "true to mark as solved, false to unmark",
                type: "boolean",
                required: true,
              },
              {
                name: "reason",
                description:
                  "Short explanation of why the post is being marked or unmarked as solved",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "mark_as_solved"
        end

        def self.requires_approval?
          true
        end

        def invoke
          if !defined?(::DiscourseSolved)
            return(
              error_response(
                I18n.t("discourse_ai.ai_bot.mark_as_solved.errors.plugin_not_installed"),
              )
            )
          end

          if reason.blank?
            return(error_response(I18n.t("discourse_ai.ai_bot.mark_as_solved.errors.no_reason")))
          end

          if !!parameters[:solved]
            result =
              DiscourseSolved::AcceptAnswer.call(
                params: {
                  post_id: parameters[:post_id],
                },
                guardian: guardian,
              )
          else
            result =
              DiscourseSolved::UnacceptAnswer.call(
                params: {
                  post_id: parameters[:post_id],
                },
                guardian: guardian,
              )
          end

          if result.success?
            { status: "success", message: I18n.t("discourse_ai.ai_bot.mark_as_solved.success") }
          else
            error_response(I18n.t("discourse_ai.ai_bot.mark_as_solved.errors.action_failed"))
          end
        end

        def description_args
          { post_id: parameters[:post_id], solved: parameters[:solved] }
        end
      end
    end
  end
end
