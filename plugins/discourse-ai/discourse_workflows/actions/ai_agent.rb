# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      class AiAgent < NodeType
        def self.identifier
          "action:ai_agent"
        end

        def self.icon
          "robot"
        end

        def self.color_key
          "pink"
        end

        def self.group
          "ai"
        end

        def self.palette_group_definition
          { icon: "robot", label_key: "discourse_workflows.add_node.categories.ai", order: 40 }
        end

        def self.property_i18n_prefix
          "discourse_ai.discourse_workflows"
        end

        def self.configuration_schema
          {
            agent_id: {
              type: :integer,
              required: true,
              options:
                ::AiAgent
                  .where(enabled: true)
                  .order(:name)
                  .pluck(:id, :name)
                  .map { |id, name| { value: id, label: name } },
              ui: {
                control: :select,
              },
            },
            input: {
              type: :string,
              ui: {
                control: :textarea,
                rows: 6,
              },
            },
          }
        end

        def self.output_schema
          { result: :string }
        end

        def self.metadata
          {
            agents:
              ::AiAgent
                .where(enabled: true)
                .order(:name)
                .pluck(:id, :name)
                .map { |id, name| { id: id, name: name } },
          }
        end

        attr_reader :logs

        def execute(exec_ctx)
          @logs = []
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)

          agent_id = config["agent_id"]
          input = config["input"]

          agent_record =
            ::AiAgent.find_by(id: agent_id) || raise("AI Agent with id #{agent_id} not found")

          raise "AI Agent '#{agent_record.name}' is disabled" if !agent_record.enabled

          @logs << "Agent: #{agent_record.name}"
          @logs << "LLM: #{agent_record.default_llm_id}"
          @logs << "Input: #{input.to_s[0..200]}"

          agent_instance = agent_record.class_instance.new
          bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_instance)

          bot_context =
            DiscourseAi::Agents::BotContext.new(
              user: Discourse.system_user,
              messages: [{ type: :user, content: input }],
              feature_name: "workflow",
            )

          result = +""
          tool_calls = 0

          bot.reply(bot_context) do |partial, _, type|
            if type == :tool_call
              tool_calls += 1
              @logs << "Tool call: #{partial}" if partial.is_a?(String)
            elsif type == :structured_output
              result = partial.to_s
            elsif type.blank?
              result << partial
            end
          end

          @logs << "Tool calls: #{tool_calls}" if tool_calls > 0
          @logs << "Result length: #{result.size} chars"

          items = exec_ctx.input_items.map { |_item| { "json" => { "result" => result } } }
          [items]
        end
      end
    end
  end
end
