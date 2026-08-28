# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AiAgent
        class V1 < DiscourseWorkflows::NodeType
          RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
          RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"

          I18N_PREFIX = "discourse_ai.discourse_workflows.ai_agent"

          PreparedPrompt = Data.define(:content, :sent_upload_ids, :unusable)

          ON_UNUSABLE_UPLOAD_SKIP = "skip"
          ON_UNUSABLE_UPLOAD_FAIL = "fail"

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
              run_scope: {
                parameter: "mode",
                values: {
                  RUN_ONCE_FOR_EACH_ITEM => "per_item",
                  RUN_ONCE_FOR_ALL_ITEMS => "all_items",
                },
              },
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
                    "unusable_uploads" => {
                      "type" => "array",
                      "items" => {
                        "type" => "object",
                        "properties" => {
                          "upload_id" => {
                            "type" => "integer",
                          },
                          "filename" => {
                            "type" => "string",
                          },
                          "reason" => {
                            "type" => "string",
                          },
                        },
                      },
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
              mode: {
                type: :options,
                required: true,
                options: [RUN_ONCE_FOR_EACH_ITEM, RUN_ONCE_FOR_ALL_ITEMS],
                default: RUN_ONCE_FOR_EACH_ITEM,
                no_data_expression: true,
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
              on_unusable_upload: {
                type: :options,
                required: false,
                options: [ON_UNUSABLE_UPLOAD_SKIP, ON_UNUSABLE_UPLOAD_FAIL],
                default: ON_UNUSABLE_UPLOAD_SKIP,
                no_data_expression: true,
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
            mode = exec_ctx.get_node_parameter("mode", 0, default: RUN_ONCE_FOR_EACH_ITEM)
            validate_mode!(mode)

            return [[run_once_for_all_items(exec_ctx)]] if mode == RUN_ONCE_FOR_ALL_ITEMS

            items =
              exec_ctx.input_items.map.with_index do |item, item_index|
                output =
                  run_agent(
                    agent_config(exec_ctx, item_index),
                    exec_ctx.log,
                    runner(exec_ctx, item_index),
                  )

                wrap(output, paired_item: exec_ctx.paired_item_for(item))
              end

            [items]
          end

          private

          def run_once_for_all_items(exec_ctx)
            output = run_agent(agent_config(exec_ctx, 0), exec_ctx.log, runner(exec_ctx, 0))

            wrap(
              output,
              paired_item: exec_ctx.input_items.map { |item| exec_ctx.paired_item_for(item) },
            )
          end

          def agent_config(exec_ctx, item_index)
            {
              "agent_id" => exec_ctx.get_node_parameter("agent_id", item_index),
              "llm_model_id" => exec_ctx.get_node_parameter("llm_model_id", item_index),
              "prompt" => exec_ctx.get_node_parameter("prompt", item_index),
              "upload_ids" => exec_ctx.get_node_parameter("upload_ids", item_index),
              "on_unusable_upload" =>
                exec_ctx.get_node_parameter(
                  "on_unusable_upload",
                  item_index,
                  default: ON_UNUSABLE_UPLOAD_SKIP,
                ),
            }
          end

          def runner(exec_ctx, item_index)
            exec_ctx.actor_from_parameter("runner_username", item_index, default: "system")
          end

          def validate_mode!(mode)
            return if [RUN_ONCE_FOR_ALL_ITEMS, RUN_ONCE_FOR_EACH_ITEM].include?(mode)

            raise_node_error!(node_t("errors.invalid_mode", mode: mode))
          end

          # agent_id and llm_model_id cannot be per-item expressions, so a multi-item run
          # resolves the same agent, agent class and LLM every time
          def resolved_agent(agent_id, llm_model_id)
            @resolved_agents ||= {}
            @resolved_agents[[agent_id, llm_model_id]] ||= begin
              agent_record = ::AiAgent.find_by(id: agent_id)
              if agent_record.nil?
                raise_node_error!(node_t("errors.agent_not_found", agent_id: agent_id))
              end

              if !agent_record.enabled
                raise_node_error!(node_t("errors.agent_disabled", agent: agent_record.name))
              end

              [
                agent_record,
                agent_record.class_instance,
                resolve_llm_model(agent_record, llm_model_id),
              ]
            end
          end

          def resolve_llm_model(agent_record, requested_llm_model_id)
            if agent_record.force_default_llm?
              llm_model =
                ::LlmModel.find_by(id: agent_record.default_llm_id) if agent_record.default_llm_id
              return llm_model if llm_model.present?

              raise_node_error!(
                node_t("errors.locked_default_llm_missing", agent: agent_record.name),
              )
            end

            if requested_llm_model_id.present?
              llm_model = ::LlmModel.find_by(id: requested_llm_model_id)
              return llm_model if llm_model.present?

              raise_node_error!(
                node_t("errors.llm_not_found", llm_model_id: requested_llm_model_id),
              )
            end

            [agent_record.default_llm_id, SiteSetting.ai_default_llm_model].each do |llm_model_id|
              llm_model = ::LlmModel.find_by(id: llm_model_id) if llm_model_id.present?
              return llm_model if llm_model.present?
            end

            raise_node_error!(node_t("errors.no_llm_configured", agent: agent_record.name))
          end

          def prompt_content(config, agent_record, llm_model, guardian, log)
            prompt = config["prompt"].to_s
            requested = normalize_upload_ids(config["upload_ids"])
            if requested.blank?
              return PreparedPrompt.new(content: prompt, sent_upload_ids: [], unusable: [])
            end

            uploads =
              ::DiscourseAi::Completions::PromptMessagesBuilder.uploads_for_prompt(
                requested,
              ).index_by(&:id)
            sendable =
              sendable_upload_ids(
                requested.filter_map { |upload_id| uploads[upload_id] },
                agent_record,
                llm_model,
                guardian,
              )
            log.info("Attachments: #{sendable.size} of #{requested.size} upload(s)")

            unusable =
              report_unusable_uploads(
                requested - sendable,
                uploads,
                agent_record,
                guardian,
                log,
                config["on_unusable_upload"],
              )

            content =
              if sendable.blank?
                prompt
              else
                [prompt, *sendable.map { |upload_id| { upload_id: upload_id } }]
              end

            PreparedPrompt.new(content: content, sent_upload_ids: sendable, unusable: unusable)
          end

          def sendable_upload_ids(uploads, agent_record, llm_model, guardian)
            allowed_attachment_types = llm_model.allowed_attachment_types

            ::DiscourseAi::Completions::PromptMessagesBuilder.filtered_upload_ids_from_uploads(
              uploads,
              include_image_uploads: agent_record.vision_enabled,
              include_document_uploads: allowed_attachment_types.present?,
              allowed_attachment_types: allowed_attachment_types,
              guardian: guardian,
            ).to_a
          end

          def report_unusable_uploads(
            upload_ids,
            uploads,
            agent_record,
            guardian,
            log,
            on_unusable_upload
          )
            return [] if upload_ids.blank?

            records =
              upload_ids.map do |upload_id|
                unusable_upload_record(upload_id, uploads[upload_id], agent_record, guardian)
              end
            reasons = records.map { |record| record["reason"] }

            raise_node_error!(reasons.join(" ")) if on_unusable_upload == ON_UNUSABLE_UPLOAD_FAIL

            log_upload_messages(reasons, log, :warn)
            records
          end

          def report_encode_failures(skips, sendable, log, on_unusable_upload)
            skips = skips.select { |skip| sendable.include?(skip[:upload_id]) }
            return [] if skips.blank?

            records =
              skips.map do |skip|
                {
                  "upload_id" => skip[:upload_id],
                  "filename" => skip[:filename],
                  "reason" =>
                    node_t(
                      "uploads.encode_failed",
                      filename: skip[:filename].to_s.truncate(100),
                      reason: skip[:message],
                    ),
                }
              end

            level = on_unusable_upload == ON_UNUSABLE_UPLOAD_FAIL ? :error : :warn
            log_upload_messages(records.map { |record| record["reason"] }, log, level)
            records
          end

          def log_upload_messages(messages, log, level)
            messages.each { |message| log.public_send(level, message) }
          end

          def unusable_upload_record(upload_id, upload, agent_record, guardian)
            {
              "upload_id" => upload_id,
              "filename" => upload&.original_filename,
              "reason" => unusable_upload_message(upload_id, upload, agent_record, guardian),
            }
          end

          def unusable_upload_message(upload_id, upload, agent_record, guardian)
            return node_t("uploads.not_found", upload_id: upload_id) if upload.blank?

            filename = (upload.original_filename.presence || "upload #{upload.id}").truncate(100)
            encoder = ::DiscourseAi::Completions::UploadEncoder

            return node_t("uploads.not_visible", filename:) if !guardian.can_see_upload?(upload)
            return node_t("uploads.not_allowed", filename:) if !encoder.image?(upload)

            if !agent_record.vision_enabled
              return node_t("uploads.vision_disabled", filename:, agent: agent_record.name)
            end

            node_t(
              "uploads.unsupported_image",
              filename:,
              formats: encoder::SUPPORTED_IMAGE_EXTENSIONS.join(", "),
            )
          end

          def node_t(key, **args)
            I18n.t("#{I18N_PREFIX}.#{key}", **args)
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
            prompt = config["prompt"].to_s
            agent_record, agent_class, llm_model =
              resolved_agent(config["agent_id"], config["llm_model_id"])
            agent_instance = agent_class.new

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

            prepared = prompt_content(config, agent_record, llm_model, runner.guardian, log)

            bot_context =
              DiscourseAi::Agents::BotContext.new(
                user: runner,
                guardian: runner.guardian,
                messages: [{ type: :user, content: prepared.content }],
                feature_name: "workflow",
              )

            result = +""
            tool_calls = 0

            execution_context = ::DiscourseAi::Completions::ExecutionContext.new

            bot.reply(bot_context, execution_context: execution_context) do |partial, _, type|
              if type == :tool_call
                tool_calls += 1
                log.info("Tool call: #{partial}") if partial.is_a?(String)
              elsif type == :structured_output
                result = partial.to_s
              elsif type.blank?
                result << partial
              end
            end

            encode_failures =
              report_encode_failures(
                execution_context.upload_skips,
                prepared.sent_upload_ids,
                log,
                config["on_unusable_upload"],
              )

            log.info("Tool calls: #{tool_calls}") if tool_calls > 0
            log.info("Result length: #{result.size} chars")

            { "result" => result, "unusable_uploads" => prepared.unusable + encode_failures }
          end
        end
      end
    end
  end
end
