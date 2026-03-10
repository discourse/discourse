# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class AiHelper < Base
        AGENT_MAP = {
          "proofread" => DiscourseAi::Agents::Proofreader,
          "explain" => DiscourseAi::Agents::Tutor,
          "smart_dates" => DiscourseAi::Agents::SmartDates,
          "title_suggestions" => DiscourseAi::Agents::TitlesGenerator,
          "markdown_tables" => DiscourseAi::Agents::MarkdownTableGenerator,
          "custom_prompt" => DiscourseAi::Agents::CustomPrompt,
          "translator" => DiscourseAi::Agents::Translator,
        }.freeze

        SANITIZE_REGEX_STR =
          %w[term context topic replyTo input output result]
            .map { |tag| "<#{tag}>\\n?|\\n?</#{tag}>" }
            .join("|")

        SANITIZE_REGEX = Regexp.new(SANITIZE_REGEX_STR, Regexp::IGNORECASE | Regexp::MULTILINE)

        def self.can_handle?(feature_name)
          feature_name&.start_with?("ai_helper:")
        end

        def initialize(feature_name, agent_prompt_override = nil)
          @agent_class =
            AGENT_MAP.fetch(feature_name) do
              raise ArgumentError, "Unsupported AI Helper mode '#{feature_name}'"
            end
          super(feature_name, agent_prompt_override)
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args || {}
          input = args[:input].presence || raise(ArgumentError, "ai_helper evals require :input")
          user = build_user(args[:locale])
          response =
            generate_prompt(
              llm: llm,
              input: input,
              user: user,
              force_default_locale: args.fetch(:force_default_locale, false),
              custom_prompt: args[:custom_prompt],
              execution_context:,
            )

          formatted = format_response(response)
          wrap_result(formatted, { feature_name: feature_name })
        end

        private

        attr_reader :feature_name, :agent_class

        def build_user(locale)
          return Discourse.system_user if locale.blank?

          User.new.tap do |user|
            user.admin = true
            user.locale = locale
          end
        end

        def generate_prompt(
          llm:,
          input:,
          user:,
          force_default_locale:,
          custom_prompt:,
          execution_context:
        )
          bot = build_bot(llm, user)
          user_input = build_user_input(input, custom_prompt)
          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              skip_show_thinking: true,
              feature_name: "ai_helper:#{feature_name}",
              messages: [{ type: :user, content: user_input }],
              format_dates: feature_name == "smart_dates",
              custom_instructions: custom_locale_instructions(user, force_default_locale),
            )
          context = attach_user_context(context, user, force_default_locale: force_default_locale)

          capture_response(bot, context, execution_context:)
        end

        def build_user_input(input, custom_prompt)
          if feature_name == "custom_prompt" && custom_prompt.present?
            return "<input>#{custom_prompt}:\n#{input}</input>"
          end

          "<input>#{input}</input>"
        end

        def build_bot(llm, user)
          agent = resolve_agent(agent_class: agent_class)

          DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm)
        end

        def capture_response(bot, context, execution_context:)
          schema_info = bot.agent.response_format&.first

          if schema_info.present?
            capture_structured_response(
              bot,
              context,
              schema_key: schema_info["key"],
              schema_type: schema_info["type"],
              execution_context:,
            )
          else
            capture_plain_response(bot, context, execution_context:)
          end
        end

        def custom_locale_instructions(user, force_default_locale)
          locale = SiteSetting.default_locale
          locale = user.effective_locale if !force_default_locale && user
          locale_hash = LocaleSiteSetting.language_names[locale]

          if locale != "en" && locale_hash
            locale_description = "#{locale_hash["name"]} (#{locale_hash["nativeName"]})"
            "It is imperative that you write your answer in #{locale_description}, you are interacting with a #{locale_description} speaking user. Leave tag names in English."
          else
            nil
          end
        end

        def attach_user_context(context, user, force_default_locale:)
          locale = SiteSetting.default_locale
          locale = user.locale if user && !force_default_locale

          locale_hash = LocaleSiteSetting.language_names[locale]
          context.user_language = locale_hash&.[]("name")

          if user
            timezone = user&.user_option&.timezone || "UTC"
            current_time = Time.now.in_time_zone(timezone)

            temporal_context = {
              utc_date_time: current_time.iso8601,
              local_time: current_time.strftime("%H:%M"),
              user: {
                timezone: timezone,
                weekday: current_time.strftime("%A"),
              },
            }

            context.temporal_context = temporal_context.to_json
          end

          context
        end

        def format_response(response)
          if response.is_a?(Array)
            response.map { |item| sanitize_result(item.to_s).strip }.reject(&:blank?).join("\n")
          else
            sanitize_result(response.to_s)
          end
        end

        def sanitize_result(result)
          result.gsub(SANITIZE_REGEX, "")
        end
      end
    end
  end
end
