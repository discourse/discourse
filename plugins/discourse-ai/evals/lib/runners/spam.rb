# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Spam < Base
        def self.can_handle?(full_feature_name)
          full_feature_name&.start_with?("spam:")
        end

        def initialize(feature_name)
          @feature_name = feature_name
        end

        def run(eval_case, llm)
          args = eval_case.args
          persona = resolve_persona(persona_class: DiscourseAi::Personas::SpamDetector)
          user = Discourse.system_user

          content = "- Topic title: #{args[:title]}\nPost content: #{args[:input]}"

          context =
            DiscourseAi::Personas::BotContext
              .new(
                user: user,
                skip_tool_details: true,
                feature_name: "evals/spam",
                messages: [{ type: :user, content: content }],
              )
              .tap do |ctx|
                ctx.custom_instructions = args[:custom_instructions] if args[:custom_instructions]
              end

          verdict = capture_verdict(persona, user, llm, context)

          wrap_result(verdict.to_s, { feature: feature_name })
        end

        private

        attr_reader :feature_name

        def capture_verdict(persona, user, llm, context)
          bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm)
          schema = persona.response_format&.first

          if schema.present?
            capture_structured_response(
              bot,
              context,
              schema_key: schema["key"],
              schema_type: schema["type"],
            )
          else
            capture_plain_response(bot, context)
          end
        end
      end
    end
  end
end
