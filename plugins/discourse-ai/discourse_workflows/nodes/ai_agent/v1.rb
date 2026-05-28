# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AiAgent
        class V1 < NodeType
          description(
            name: "action:ai_agent",
            version: "1.0",
            defaults: {
              icon: "robot",
              color: "pink",
            },
            group: "ai",
            available: -> { SiteSetting.discourse_ai_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_ai",
            i18n_prefix: "discourse_ai.discourse_workflows",
            capabilities: {
              run_scope: "per_item",
            },
            properties: {
              agent_id: {
                type: :integer,
                required: true,
                type_options: {
                  load_options_method: "agents",
                },
                no_data_expression: true,
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  action_icon: "robot",
                  action_label: "discourse_ai.ai_agent.manage_agents",
                  action_route: "adminPlugins.show.discourse-ai-agents",
                  action_route_models: ["discourse-ai"],
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                  set_from_option: {
                    agent_name: "name",
                  },
                },
              },
              agent_name: {
                type: :string,
                ui: {
                  hidden: true,
                },
              },
              prompt: {
                type: :string,
                ui: {
                  control: :textarea,
                },
              },
            },
          )

          def self.group_definition
            { icon: "robot", label_key: "discourse_workflows.add_node.categories.ai", order: 40 }
          end

          def self.load_options_context(context)
            case context.method_name
            when "agents"
              agent_options.select { |agent| context.matches_filter?(agent[:name]) }
            end
          end

          def self.agent_options
            ::AiAgent
              .where(enabled: true)
              .order(:name)
              .pluck(:id, :name)
              .map { |id, name| { id: id, name: name } }
          end

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map.with_index do |item, item_index|
                config = {
                  "agent_id" => exec_ctx.get_node_parameter("agent_id", item_index),
                  "prompt" => exec_ctx.get_node_parameter("prompt", item_index),
                }
                result = run_agent(config, exec_ctx.log)

                wrap({ "result" => result }, paired_item: exec_ctx.paired_item_for(item))
              end

            [items]
          end

          private

          def run_agent(config, log)
            agent_id = config["agent_id"]
            prompt = config["prompt"].to_s

            agent_record = ::AiAgent.find_by(id: agent_id)
            raise_node_error!("AI Agent with id #{agent_id} not found") if agent_record.nil?

            if !agent_record.enabled
              raise_node_error!("AI Agent '#{agent_record.name}' is disabled")
            end

            log.info("Agent: #{agent_record.name}")
            log.info("LLM: #{agent_record.default_llm_id}")
            log.info("Prompt: #{prompt.to_s[0..200]}")

            agent_instance = agent_record.class_instance.new
            bot = DiscourseAi::Agents::Bot.as(Discourse.system_user, agent: agent_instance)

            bot_context =
              DiscourseAi::Agents::BotContext.new(
                user: Discourse.system_user,
                messages: [{ type: :user, content: prompt }],
                feature_name: "workflow",
              )

            result = +""
            tool_calls = 0

            bot.reply(bot_context) do |partial, _, type|
              if type == :tool_call
                tool_calls += 1
                log.info("Tool call: #{partial}") if partial.is_a?(String)
              elsif type == :structured_output
                result = partial.to_s
              elsif type.blank?
                result << partial
              end
            end

            log.info("Tool calls: #{tool_calls}") if tool_calls > 0
            log.info("Result length: #{result.size} chars")

            result
          end
        end
      end
    end
  end
end
