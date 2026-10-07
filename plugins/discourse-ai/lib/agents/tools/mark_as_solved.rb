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

        def approval_title
          return super if topic.blank?

          I18n.t(
            "discourse_ai.ai_bot.chat_tool_approval.topic_title",
            topic: DiscourseAi::AiBot::ChatToolApproval.format_topic(topic),
          )
        end

        def approval_changes
          return [] if topic.blank? || !defined?(::DiscourseSolved)

          before = topic.topic_answers.includes(:post).map { |answer| answer.post.post_number }.sort
          after =
            if parameters[:solved]
              if SiteSetting.solved_allow_multiple_solutions
                (before + [post.post_number]).uniq.sort
              else
                [post.post_number]
              end
            else
              before - [post.post_number]
            end
          [
            {
              label: I18n.t("discourse_ai.ai_bot.chat_tool_approval.topic_solution_label"),
              before: solution_label(before),
              after: solution_label(after),
            },
          ]
        end

        def approval_question
          return super if post.blank?

          label =
            I18n.t("discourse_ai.ai_bot.chat_tool_approval.solution_post", number: post.post_number)
          key = parameters[:solved] ? "mark_solution_question" : "unmark_solution_question"
          I18n.t("discourse_ai.ai_bot.chat_tool_approval.#{key}", post: "[#{label}](#{post.url})")
        end

        def approval_parameters
          []
        end

        private

        def post
          @post ||= Post.find_by(id: parameters[:post_id])
        end

        def topic
          post&.topic
        end

        def solution_label(numbers)
          return I18n.t("discourse_ai.ai_bot.chat_tool_approval.no_solution") if numbers.empty?

          numbers
            .map do |number|
              I18n.t("discourse_ai.ai_bot.chat_tool_approval.solution_post", number: number)
            end
            .join(", ")
        end
      end
    end
  end
end
