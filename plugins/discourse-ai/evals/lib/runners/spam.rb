# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Spam < Base
        def self.can_handle?(full_feature_name)
          full_feature_name&.start_with?("spam:")
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args
          agent = resolve_agent(agent_class: DiscourseAi::Agents::SpamDetector)
          user = Discourse.system_user

          content = "- Topic title: #{args[:title]}\nPost content: #{args[:input]}"

          context =
            DiscourseAi::Agents::BotContext
              .new(
                user: user,
                skip_show_thinking: true,
                feature_name: "evals/spam",
                messages: [{ type: :user, content: content }],
              )
              .tap do |ctx|
                ctx.custom_instructions = args[:custom_instructions] if args[:custom_instructions]
              end

          verdict = capture_verdict(agent, user, llm, context, execution_context:)

          wrap_result(verdict.to_s, { feature: feature_name })
        end

        private

        def capture_verdict(agent, user, llm, context, execution_context:)
          bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm)
          schema = agent.response_format&.first

          if schema.present?
            capture_structured_response(
              bot,
              context,
              schema_key: schema["key"],
              schema_type: schema["type"],
              execution_context:,
            )
          else
            capture_plain_response(bot, context, execution_context:)
          end
        end
      end
    end
  end
end
