# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Summarization < Base
        def self.can_handle?(full_feature_name)
          full_feature_name&.start_with?("summarization:")
        end

        def initialize(feature_name)
          @feature_name = feature_name
        end

        def run(eval_case, llm)
          args = eval_case.args
          persona_class, strategy = persona_and_strategy
          persona, = resolve_persona(persona_class: persona_class)
          user = Discourse.system_user

          extras = {
            resource_path: "#{Discourse.base_path}/t/-/1",
            title: "Eval topic for topic summarization",
          }

          conversation = extract_conversation(args)
          content =
            conversation.each_with_index.map do |text, index|
              { poster: user.username, id: index + 1, text: text }
            end

          context =
            DiscourseAi::Personas::BotContext.new(
              user: user,
              skip_tool_details: true,
              feature_name: "evals/#{feature_name}",
              resource_url: "#{Discourse.base_path}/t/-/1",
              messages: strategy.as_llm_messages(content, extras: extras),
            )

          summary = capture_summary(persona, user, llm, context)

          wrap_result(summary, { feature: feature_name })
        end

        private

        attr_reader :feature_name

        def persona_and_strategy
          if regular_summaries?
            [
              DiscourseAi::Personas::Summarizer,
              DiscourseAi::Summarization::Strategies::TopicSummary.new(nil),
            ]
          elsif gists?
            [
              DiscourseAi::Personas::ShortSummarizer,
              DiscourseAi::Summarization::Strategies::HotTopicGists.new(nil),
            ]
          else
            raise "Unknown summary type"
          end
        end

        def capture_summary(persona, user, llm, context)
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

        def extract_conversation(args)
          messages =
            if args[:conversation].present?
              args[:conversation]
            elsif args[:input].present?
              [args[:input]]
            else
              []
            end

          if messages.empty?
            raise ArgumentError, "Summarization evals must define :conversation or :input"
          end

          messages
        end

        def regular_summaries?
          feature_name == "topic_summaries"
        end

        def gists?
          feature_name == "gists"
        end
      end
    end
  end
end
