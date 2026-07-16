# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AiAgent
        class V1 < DiscourseWorkflows::NodeType
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
            output_contracts: [
              {
                schema: {
                  "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
                  "type" => "object",
                  "properties" => {
                    "result" => {
                      "type" => "string",
                    },
                  },
                },
              },
            ],
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
                    agent_force_default_llm: "force_default_llm",
                    agent_resolved_llm_name: "resolved_llm_name",
                  },
                },
              },
              agent_name: {
                type: :string,
                ui: {
                  hidden: true,
                },
              },
              agent_force_default_llm: {
                type: :boolean,
                default: false,
                ui: {
                  hidden: true,
                },
              },
              agent_resolved_llm_name: {
                type: :string,
                ui: {
                  hidden: true,
                },
              },
              llm_model_id: {
                type: :integer,
                required: false,
                type_options: {
                  load_options_method: "llm_models",
                },
                no_data_expression: true,
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                  none: "discourse_ai.discourse_workflows.ai_agent.llm_model_default",
                  none_label_field: "agent_resolved_llm_name",
                  none_label_i18n_key:
                    "discourse_ai.discourse_workflows.ai_agent.llm_model_default_with_name",
                },
                display_options: {
                  hide: {
                    agent_force_default_llm: [true],
                  },
                },
              },
              forced_llm_notice: {
                type: :notice,
                display_options: {
                  show: {
                    agent_force_default_llm: [true],
                  },
                },
              },
              runner_username: {
                type: :string,
                required: false,
                default: "system",
                ui: {
                  control: :actor,
                },
              },
              prompt: {
                type: :string,
                ui: {
                  control: :textarea,
                },
              },
              upload_ids: {
                type: :array,
                required: false,
                default: [],
                ui: {
                  control: :multi_input,
                  expression: true,
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
            when "llm_models"
              llm_model_options(context)
            end
          end

          def self.agent_options
            agents =
              ::AiAgent
                .where(enabled: true)
                .order(:name)
                .pluck(:id, :name, :default_llm_id, :force_default_llm)

            site_default_llm_id = SiteSetting.ai_default_llm_model.presence&.to_i
            llm_model_ids = agents.map { |_id, _name, default_llm_id, _force| default_llm_id }
            llm_model_ids << site_default_llm_id
            llm_models_by_id = ::LlmModel.where(id: llm_model_ids.compact.uniq).index_by(&:id)

            default_llm = llm_models_by_id[site_default_llm_id]

            agents.map do |id, name, default_llm_id, force_default_llm|
              configured_llm = llm_models_by_id[default_llm_id]
              resolved_llm = force_default_llm ? configured_llm : configured_llm || default_llm
              {
                id: id,
                name: name,
                default_llm_id: default_llm_id,
                force_default_llm: force_default_llm,
                resolved_llm_id: resolved_llm&.id,
                resolved_llm_name: resolved_llm&.display_name,
              }
            end
          end

          def self.llm_model_options(context)
            ::LlmModel
              .order(:display_name)
              .pluck(:id, :display_name)
              .filter_map do |id, display_name|
                next if display_name.blank?

                { id: id, name: display_name }
              end
              .select { |llm_model| context.matches_filter?(llm_model[:name]) }
          end

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map.with_index do |item, item_index|
                config = {
                  "agent_id" => exec_ctx.get_node_parameter("agent_id", item_index),
                  "llm_model_id" => exec_ctx.get_node_parameter("llm_model_id", item_index),
                  "prompt" => exec_ctx.get_node_parameter("prompt", item_index),
                  "upload_ids" => exec_ctx.get_node_parameter("upload_ids", item_index),
                }
                runner =
                  exec_ctx.actor_from_parameter("runner_username", item_index, default: "system")
                result = run_agent(config, exec_ctx.log, runner)

                wrap({ "result" => result }, paired_item: exec_ctx.paired_item_for(item))
              end

            [items]
          end

          private

          def resolve_llm_model(agent_record, requested_llm_model_id)
            if agent_record.force_default_llm?
              llm_model =
                ::LlmModel.find_by(id: agent_record.default_llm_id) if agent_record.default_llm_id
              return llm_model if llm_model.present?

              raise_node_error!(
                I18n.t(
                  "discourse_ai.discourse_workflows.ai_agent.errors.locked_default_llm_missing",
                  agent: agent_record.name,
                ),
              )
            end

            if requested_llm_model_id.present?
              llm_model = ::LlmModel.find_by(id: requested_llm_model_id)
              return llm_model if llm_model.present?

              raise_node_error!(
                I18n.t(
                  "discourse_ai.discourse_workflows.ai_agent.errors.llm_not_found",
                  llm_model_id: requested_llm_model_id,
                ),
              )
            end

            [agent_record.default_llm_id, SiteSetting.ai_default_llm_model].each do |llm_model_id|
              llm_model = ::LlmModel.find_by(id: llm_model_id) if llm_model_id.present?
              return llm_model if llm_model.present?
            end

            raise_node_error!(
              I18n.t(
                "discourse_ai.discourse_workflows.ai_agent.errors.no_llm_configured",
                agent: agent_record.name,
              ),
            )
          end

          def prompt_content(prompt, upload_ids, agent_record, llm_model, guardian, log)
            upload_ids = filtered_upload_ids(upload_ids, agent_record, llm_model, guardian)
            return prompt if upload_ids.blank?

            log.info("Attachments: #{upload_ids.size} upload(s)")
            [prompt, *upload_ids.map { |upload_id| { upload_id: upload_id } }]
          end

          def filtered_upload_ids(upload_ids, agent_record, llm_model, guardian)
            upload_ids = normalize_upload_ids(upload_ids)
            return [] if upload_ids.blank?

            ::DiscourseAi::Completions::PromptMessagesBuilder.filtered_upload_ids_for_prompt(
              upload_ids,
              include_image_uploads: agent_record.vision_enabled,
              include_document_uploads: llm_model.allowed_attachment_types.present?,
              allowed_attachment_types: llm_model.allowed_attachment_types,
              guardian: guardian,
            ) || []
          end

          def normalize_upload_ids(upload_ids)
            case upload_ids
            when String
              parsed = parse_upload_ids_json(upload_ids)
              return normalize_upload_ids(parsed) if parsed

              upload_ids.split(",")
            when Array
              upload_ids.flatten
            else
              Array.wrap(upload_ids)
            end.filter_map do |upload_id|
              id = Integer(upload_id, exception: false)
              id if id&.positive?
            end
          end

          def parse_upload_ids_json(upload_ids)
            JSON.parse(upload_ids)
          rescue JSON::ParserError, TypeError
            nil
          end

          def run_agent(config, log, runner)
            agent_id = config["agent_id"]
            prompt = config["prompt"].to_s

            agent_record = ::AiAgent.find_by(id: agent_id)
            raise_node_error!("AI Agent with id #{agent_id} not found") if agent_record.nil?

            if !agent_record.enabled
              raise_node_error!("AI Agent '#{agent_record.name}' is disabled")
            end

            agent_instance = agent_record.class_instance.new
            llm_model = resolve_llm_model(agent_record, config["llm_model_id"])

            log.info("Agent: #{agent_record.name}")
            log.info("Runner: #{runner.username}")
            log.info("LLM: #{llm_model.display_name} (#{llm_model.id})")
            log.info("Prompt: #{prompt.to_s[0..200]}")

            bot =
              DiscourseAi::Agents::Bot.as(
                Discourse.system_user,
                agent: agent_instance,
                model: llm_model,
              )

            content =
              prompt_content(
                prompt,
                config["upload_ids"],
                agent_record,
                llm_model,
                runner.guardian,
                log,
              )

            bot_context =
              DiscourseAi::Agents::BotContext.new(
                user: runner,
                guardian: runner.guardian,
                messages: [{ type: :user, content: content }],
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
