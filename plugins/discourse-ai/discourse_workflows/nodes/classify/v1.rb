# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Classify
        class V1 < DiscourseWorkflows::NodeType
          OUTPUT_KEY = "classification"
          MAX_IMAGE_PIXELS = 1_600_000

          description(
            name: "action:classify",
            version: "1.0",
            defaults: {
              icon: "scale-balanced",
              color: "violet",
            },
            group: "ai",
            available: -> { SiteSetting.discourse_ai_enabled && ::DecisionModel.exists? },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_decision_model",
            i18n_prefix: "discourse_ai.discourse_workflows",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [
              {
                mode: :merge,
                schema: DiscourseWorkflows::Schema.document(OUTPUT_KEY => { "type" => "object" }),
              },
            ],
            properties: {
              decision_model_id: {
                type: :integer,
                required: true,
                type_options: {
                  load_options_method: "decision_models",
                },
                no_data_expression: true,
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  action_icon: "scale-balanced",
                  action_label: "discourse_ai.decision_models.manage",
                  action_route: "adminPlugins.show.discourse-ai-decision-models",
                  action_route_models: ["discourse-ai"],
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                },
              },
              text: {
                type: :string,
                required: true,
                default: "={{ $json.post.raw }}",
                ui: {
                  control: :textarea,
                },
              },
              upload_ids: {
                type: :array,
                default: [],
                ui: {
                  control: :multi_input,
                  expression: true,
                },
              },
              questions: {
                type: :fixed_collection,
                required: true,
                type_options: {
                  multiple_values: true,
                },
                options: [
                  {
                    name: "values",
                    values: {
                      name: {
                        type: :string,
                        required: true,
                        no_data_expression: true,
                      },
                      type: {
                        type: :options,
                        required: true,
                        options: DiscourseAi::Decisions::Question::TYPES.map(&:to_s),
                        default: "yes_no",
                        no_data_expression: true,
                      },
                      instructions: {
                        type: :string,
                        required: true,
                        ui: {
                          control: :textarea,
                        },
                      },
                      choices: {
                        type: :array,
                        default: [],
                        no_data_expression: true,
                        display_options: {
                          show: {
                            type: %w[choice],
                          },
                        },
                        ui: {
                          control: :multi_input,
                        },
                      },
                      levels: {
                        type: :array,
                        default: [],
                        no_data_expression: true,
                        display_options: {
                          show: {
                            type: %w[score],
                          },
                        },
                        ui: {
                          control: :multi_input,
                        },
                      },
                    },
                  },
                ],
              },
            },
          )

          # Answer keys come from the configured questions, so the exact shape is
          # resolved from the configuration rather than declared as a contract.
          def self.output_schemas(configuration = {}, input_schemas: [])
            rows =
              DiscourseWorkflows::CollectionParameters.rows(
                (configuration || {}).deep_stringify_keys,
                "questions",
              )

            answers =
              rows
                .grep(Hash)
                .each_with_object({}) do |row, properties|
                  key = row["name"].to_s.strip
                  next if key.blank?

                  properties[key] = answer_schema(row["type"].to_s)
                end

            schema =
              DiscourseWorkflows::Schema.document(
                OUTPUT_KEY => {
                  "type" => "object",
                  "properties" => answers,
                },
              )
            input_schema = DiscourseWorkflows::Schema.union(*Array(input_schemas).compact)
            [DiscourseWorkflows::Schema.resolve(schema, mode: :merge, input_schema:)]
          end

          def self.answer_schema(type)
            properties = {
              "type" => {
                "type" => "string",
              },
              "reason" => {
                "type" => %w[string null],
              },
            }
            case type
            when "yes_no"
              properties["probability"] = { "type" => "number" }
            when "choice", "score"
              properties["probabilities"] = { "type" => "object" }
              properties["confidence"] = { "type" => %w[number null] }
              if type == "choice"
                properties["choice"] = { "type" => "string" }
              else
                properties["score"] = { "type" => "number" }
                properties["level"] = { "type" => "string" }
              end
            end
            properties.each { |key, property| property["x-optional"] = true if key != "type" }
            { "type" => "object", "properties" => properties }
          end

          def self.group_definition
            { icon: "robot", label_key: "discourse_workflows.add_node.categories.ai", order: 40 }
          end

          def self.load_options_context(context)
            return if context.method_name != "decision_models"

            ::DecisionModel
              .order(:display_name)
              .pluck(:id, :display_name)
              .map { |id, display_name| { id: id, name: display_name } }
              .select { |decision_model| context.matches_filter?(decision_model[:name]) }
          end

          def execute(exec_ctx)
            decision_model = find_decision_model(exec_ctx)

            [
              exec_ctx.each_item do |item, item_index|
                answers = classify(exec_ctx, decision_model, item_index)
                wrap(item.fetch("json") { {} }.merge(OUTPUT_KEY => answers))
              end,
            ]
          end

          private

          def find_decision_model(exec_ctx)
            id = exec_ctx.get_node_parameter("decision_model_id", 0)
            decision_model = ::DecisionModel.find_by(id: id)
            raise_node_error!(error_text("decision_model_not_found", id: id)) if decision_model.nil?

            decision_model
          end

          def classify(exec_ctx, decision_model, item_index)
            text = exec_ctx.get_node_parameter("text", item_index)
            questions = exec_ctx.get_node_parameter("questions.values", item_index, default: [])
            images = images_for(exec_ctx.get_node_parameter("upload_ids", item_index, default: []))
            exec_ctx.log.info(
              "Decision model: #{decision_model.display_name}, images: #{images.size}",
            )

            questions =
              questions.map do |question|
                next question if !question.is_a?(Hash)

                question = question.symbolize_keys
                question[:choices] = nil if question[:type] != "choice"
                question[:levels] = nil if question[:type] != "score"
                question
              end
            result =
              decision_model.decide(
                text,
                questions:,
                images:,
                feature_name: "workflow",
                user: Discourse.system_user,
              )
            refusals = result.refusals
            if refusals.present?
              exec_ctx.log.warn(
                "Decision model refused questions: #{refusals.map(&:name).join(", ")}",
              )
            end
            result.answers.transform_values(&:to_h)
          rescue DiscourseAi::Decisions::Error => e
            raise_node_error!(
              error_text(
                "classify_failed",
                decision_model: decision_model.display_name,
                error: e.message,
              ),
              item_index: item_index,
            )
          end

          def images_for(upload_ids)
            encoder = DiscourseAi::Completions::UploadEncoder
            upload_ids = encoder.normalize_upload_ids(upload_ids)
            return [] if upload_ids.empty?

            missing = upload_ids - ::Upload.where(id: upload_ids).pluck(:id)
            skips = []
            images =
              begin
                encoder.encode(upload_ids:, max_pixels: MAX_IMAGE_PIXELS, skips:)
              rescue StandardError => e
                raise DiscourseAi::Decisions::InvalidRequest,
                      "Could not prepare images: #{e.message}"
              end

            # Answering without every image would record a confident verdict on partial evidence.
            reasons =
              missing.map { |upload_id| upload_error_text("not_found", upload_id:) } +
                skips.map { |skip| upload_error_text("skipped", **skip) }
            raise DiscourseAi::Decisions::InvalidRequest, reasons.join(". ") if reasons.any?

            images.map { |image| "data:#{image[:mime_type]};base64,#{image[:base64]}" }
          end

          def error_text(key, **args)
            I18n.t("discourse_ai.discourse_workflows.classify.errors.#{key}", **args)
          end

          def upload_error_text(key, **args)
            I18n.t("discourse_ai.discourse_workflows.uploads.#{key}", **args)
          end
        end
      end
    end
  end
end
