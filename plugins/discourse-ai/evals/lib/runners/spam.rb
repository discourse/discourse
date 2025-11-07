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
          user = Discourse.system_user
          persona_id =
            DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::SpamDetector]

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

          persona = AiPersona.find_by_id_from_cache(persona_id).class_instance.new

          bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm)

          verdict = nil

          buffer_blk =
            Proc.new do |partial, _, type|
              if type == :structured_output
                json_summary_schema_key = persona.response_format&.first.to_h
                verdict = partial.read_buffered_property(json_summary_schema_key["key"]&.to_sym)
              elsif type.blank?
                # Assume response is a regular completion.
                verdict = partial
              end
            end

          bot.reply(context, &buffer_blk)

          verdict.to_s
        end

        private

        attr_reader :feature_name
      end
    end
  end
end
