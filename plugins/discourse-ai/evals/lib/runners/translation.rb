# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Translation < Base
        FEATURE_PERSONA_MAP = {
          "locale_detector" => DiscourseAi::Personas::LocaleDetector,
          "post_raw_translator" => DiscourseAi::Personas::PostRawTranslator,
          "topic_title_translator" => DiscourseAi::Personas::TopicTitleTranslator,
          "short_text_translator" => DiscourseAi::Personas::ShortTextTranslator,
        }

        def self.can_handle?(feature_name)
          feature_name&.start_with?("translation:")
        end

        def initialize(feature_name)
          @operation = feature_name.split(":").last
          if !OPERATIONS.key?(@operation)
            raise ArgumentError, "Unsupported translation feature '#{feature_name}'"
          end
        end

        def run(eval_case, llm)
          raw_args = eval_case.args
          if raw_args.present? && !raw_args.is_a?(Hash)
            raise ArgumentError, "Translation evals expect args defined as a Hash"
          end

          args = (raw_args || {}).deep_symbolize_keys
          case_defs = args.delete(:cases)

          if case_defs.present?
            case_defs.map do |case_args|
              normalized_args = args.merge(case_args)
              run_case(normalized_args, llm, wrap: true)
            end
          else
            run_case(args, llm, wrap: false)
          end
        end

        private

        attr_reader :operation

        def run_case(case_args, llm, wrap:)
          content = extract_content(case_args)
          raise ArgumentError, "Translation evals require :input or :conversation" if content.blank?

          output =
            if operation == "locale_detector"
              detect_locale(content, llm)
            else
              target =
                case_args[:target_locale].presence ||
                  raise(ArgumentError, "Translation evals require :target_locale")
              translate_content(content, target, llm)
            end

          wrap ? build_payload(case_args, content, output) : output
        end

        def detect_locale(content, llm)
          persona, user = persona_for_operation
          context =
            DiscourseAi::Personas::BotContext.new(
              user: user,
              skip_tool_details: true,
              feature_name: "translation/#{operation}",
              messages: [{ type: :user, content: content }],
            )

          capture_response(persona, user, llm, context).strip
        end

        def translate_content(content, target_locale, llm)
          persona, user = persona_for_operation
          payload = { content:, target_locale: }.to_json
          context =
            DiscourseAi::Personas::BotContext.new(
              user: user,
              skip_tool_details: true,
              feature_name: "translation/#{operation}",
              messages: [{ type: :user, content: payload }],
            )

          capture_response(persona, user, llm, context).strip
        end

        def capture_response(persona, user, llm, context)
          bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm)
          buffer = +""

          bot.reply(context) { |partial, _, type| buffer << partial if type.blank? }

          buffer
        end

        def build_payload(case_args, content, output)
          {
            result: output,
            message: content,
            target_locale: case_args[:target_locale],
            expected_locale: case_args[:expected_locale],
          }.compact
        end

        def extract_content(case_args)
          if case_args[:conversation].present?
            Array(case_args[:conversation]).map(&:to_s).join("\n\n")
          else
            (case_args[:input] || case_args[:message]).to_s
          end
        end

        def persona_for_operation
          persona_class = FEATURE_PERSONA_MAP.fetch(operation)
          persona_id = DiscourseAi::Personas::Persona.system_personas[persona_class]

          persona_record = persona_id ? AiPersona.find_by_id_from_cache(persona_id) : nil
          persona = persona_record&.class_instance&.new || persona_class.new

          [persona, persona_record&.user || Discourse.system_user]
        end
      end
    end
  end
end
