# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class Summarization < Base
        def self.can_handle?(full_feature_name)
          full_feature_name&.start_with?("summarization:")
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args
          conversation = extract_conversation(args)
          user = Discourse.system_user

          topic =
            Topic.new(
              category: Category.last,
              title: "Eval topic for topic summarization",
              id: -99,
              user_id: user.id,
            )
          content =
            conversation.each_with_index.map do |text, index|
              { poster: user.username, id: index + 1, text: text }
            end

          agent_class, strategy = agent_and_strategy(topic)
          agent = resolve_agent(agent_class: agent_class)

          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              skip_show_thinking: true,
              feature_name: "evals/#{feature_name}",
              resource_url: "#{Discourse.base_path}/t/-/1",
              messages: strategy.as_llm_messages(content),
            )

          summary = capture_summary(agent, user, llm, context, execution_context:)

          wrap_result(summary, { feature: feature_name })
        end

        private

        def agent_and_strategy(topic)
          if regular_summaries?
            [
              DiscourseAi::Agents::Summarizer,
              DiscourseAi::Summarization::Strategies::TopicSummary.new(topic),
            ]
          elsif gists?
            [
              DiscourseAi::Agents::ShortSummarizer,
              DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic),
            ]
          else
            raise "Unknown summary type"
          end
        end

        def capture_summary(agent, user, llm, context, execution_context:)
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
