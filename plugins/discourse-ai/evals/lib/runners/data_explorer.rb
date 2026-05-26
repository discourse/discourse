# frozen_string_literal: true

require_relative "base"

module DiscourseAi
  module Evals
    module Runners
      class DataExplorer < Base
        STRUCTURED_KEYS = %i[name description sql].freeze

        def self.can_handle?(full_feature_name)
          full_feature_name&.start_with?("data_explorer:")
        end

        def run(eval_case, llm, execution_context:)
          args = eval_case.args
          agent = resolve_agent(agent_class: DiscourseDataExplorer::AiQueryGenerator)
          user = Discourse.system_user

          context =
            DiscourseAi::Agents::BotContext.new(
              user: user,
              skip_show_thinking: true,
              feature_name: "evals/data_explorer_query_generation",
              messages: [{ type: :user, content: args[:input] }],
            )

          bot = DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm)
          captured = capture_structured_fields(bot, context, execution_context:)

          sql = captured[:sql].to_s.strip
          metadata = {
            feature: feature_name,
            name: captured[:name].to_s.strip,
            description: captured[:description].to_s.strip,
          }

          wrap_result(sql, metadata)
        end

        private

        def capture_structured_fields(bot, context, execution_context:)
          buffers = STRUCTURED_KEYS.index_with { +"" }

          bot.reply(context, execution_context:) do |partial, _, type|
            if type == :structured_output
              STRUCTURED_KEYS.each do |key|
                chunk = partial.read_buffered_property(key)
                buffers[key] << chunk.to_s if chunk
              end
            elsif type.blank?
              buffers[:sql] << partial.to_s
            end
          end

          buffers
        end
      end
    end
  end
end
