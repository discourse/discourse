# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Translation < Base
        OPERATIONS = {
          "locale_detector" => DiscourseAi::Personas::LocaleDetector,
          "post_raw_translator" => DiscourseAi::Personas::PostRawTranslator,
          "topic_title_translator" => DiscourseAi::Personas::TopicTitleTranslator,
          "short_text_translator" => DiscourseAi::Personas::ShortTextTranslator,
        }.freeze

        def self.can_handle?(feature_name)
          feature_name&.start_with?("translation:")
        end

        def initialize(feature_name)
          @operation = feature_name
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
              normalized_args = args.merge(case_args.symbolize_keys)
              run_case(normalized_args, llm)
            end
          else
            run_case(args, llm)
          end
        end

        private

        attr_reader :operation

        def run_case(case_args, llm)
          content = extract_content(case_args)
          raise ArgumentError, "Translation evals require :input or :conversation" if content.blank?

          output =
            if operation == "locale_detector"
              detect_locale(content, llm)
            else
              target_locale =
                case_args[:target_locale].presence ||
                  raise(ArgumentError, "Translation evals require :target_locale")
              translate_content(content, target_locale, llm)
            end

          build_payload(case_args, content, output)
        end

        def detect_locale(content, llm)
          persona = persona_for_operation
          context =
            DiscourseAi::Personas::BotContext.new(
              user: system_user,
              skip_tool_details: true,
              feature_name: "translation/#{operation}",
              messages: [{ type: :user, content: content }],
            )

          bot = DiscourseAi::Personas::Bot.as(system_user, persona: persona, model: llm)
          capture_plain_response(bot, context).strip
        end

        def translate_content(content, target_locale, llm)
          persona = persona_for_operation
          payload = { content:, target_locale: }.to_json
          context =
            DiscourseAi::Personas::BotContext.new(
              user: system_user,
              skip_tool_details: true,
              feature_name: "translation/#{operation}",
              messages: [{ type: :user, content: payload }],
            )

          bot = DiscourseAi::Personas::Bot.as(system_user, persona: persona, model: llm)
          capture_plain_response(bot, context).strip
        end

        def build_payload(case_args, content, output)
          metadata = {
            message: content,
            target_locale: case_args[:target_locale],
            expected_locale: case_args[:expected_locale],
          }.compact

          wrap_result(output, metadata)
        end

        def extract_content(case_args)
          if case_args[:conversation].present?
            Array(case_args[:conversation]).map(&:to_s).join("\n\n")
          else
            (case_args[:input] || case_args[:message]).to_s
          end
        end

        def system_user
          @user ||= Discourse.system_user
        end

        def persona_for_operation
          persona_class = OPERATIONS.fetch(operation)
          resolve_persona(persona_class: persona_class)
        end
      end
    end
  end
end
