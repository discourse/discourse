# frozen_string_literal: true

module DiscourseAi
  module Evals
    module Runners
      class Summarization
        def self.can_handle?(full_feature_name)
          feature_name.starts_with?("summarization:")
        end

        def initialize(feature_name)
          @feature_name = feature_name
        end

        def run(eval_case, llm)
          args = eval_case.args
          user = Discourse.system_user

          if regular_summaries?
            persona_id =
              DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::Summarizer]
            strategy = DiscourseAi::Summarization::Strategies::TopicSummary.new(nil)
          elsif gists?
            persona_id =
              DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ShortSummarizer]
            strategy = DiscourseAi::Summarization::Strategies::HotTopicGists.new(nil)
          else
            raise "Unknown summary type"
          end

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
          persona = AiPersona.find_by_id_from_cache(persona_id).class_instance.new

          bot = DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm)

          summary = +""

          buffer_blk =
            Proc.new do |partial, _, type|
              if type == :structured_output
                json_summary_schema_key = persona.response_format&.first.to_h
                partial_summary =
                  partial.read_buffered_property(json_summary_schema_key["key"]&.to_sym)

                summary << partial_summary if !partial_summary.nil? && !partial_summary.empty?
              elsif type.blank?
                # Assume response is a regular completion.
                summary << partial
              end
            end

          bot.reply(context, &buffer_blk)

          summary
        end

        private

        attr_reader :feature_name

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
