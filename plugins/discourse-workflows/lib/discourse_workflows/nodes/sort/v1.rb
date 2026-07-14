# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Sort
      class V1 < NodeType
        RUN_CODE = "runCode"

        description(
          name: "action:sort",
          version: "1.0",
          defaults: {
            icon: "arrow-down-a-z",
            color: "yellow",
          },
          group: "flow",
          capabilities: {
            run_scope: "all_items",
          },
          properties: {
            type: {
              type: :options,
              required: true,
              options: %w[simple random code],
              default: "simple",
            },
            sort_fields: {
              type: :fixed_collection,
              required: false,
              display_options: {
                show: {
                  type: ["simple"],
                },
              },
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
                    field_name: {
                      type: :string,
                      required: true,
                      no_data_expression: true,
                    },
                    order: {
                      type: :options,
                      required: true,
                      options: %w[ascending descending],
                      default: "ascending",
                    },
                  },
                },
              ],
            },
            code: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  type: ["code"],
                },
              },
              no_data_expression: true,
              default: <<~JS.strip,
                // The two items to compare are in the variables a and b
                // Access the fields via a.json and b.json
                // Return -1 if a should go before b
                // Return 1 if b should go before a
                // Return 0 if there's no difference

                if (a.json.myField < b.json.myField) {
                  return -1;
                }
                if (a.json.myField > b.json.myField) {
                  return 1;
                }
                return 0;
              JS
              ui: {
                control: :code,
              },
              control_options: {
                height: 200,
                lang: :javascript,
              },
            },
          },
        )

        def execute(exec_ctx)
          type = exec_ctx.get_node_parameter("type", 0, default: "simple")
          config = { "type" => type, "code" => exec_ctx.get_node_parameter("code", 0) }

          items =
            case type
            when "simple"
              sort_simple(exec_ctx)
            when "random"
              sort_random(exec_ctx.input_items)
            when "code"
              sort_code(exec_ctx, config)
            else
              exec_ctx.input_items.dup
            end
          [items]
        end

        private

        def sort_simple(exec_ctx)
          sort_fields = exec_ctx.get_node_parameter("sort_fields.values", 0, default: [])
          return exec_ctx.input_items.dup if sort_fields.blank?

          exec_ctx.input_items.sort { |a, b| compare_items(a, b, sort_fields) }
        end

        def compare_items(a, b, sort_fields)
          sort_fields.each do |field|
            field_name = field["field_name"]
            direction = field["order"] == "descending" ? -1 : 1

            val_a = dig_field(a.fetch("json") { {} }, field_name)
            val_b = dig_field(b.fetch("json") { {} }, field_name)

            val_a = val_a.downcase if val_a.is_a?(String)
            val_b = val_b.downcase if val_b.is_a?(String)

            cmp = (val_a <=> val_b)

            cmp = nil_aware_compare(val_a, val_b) if cmp.nil?

            return cmp * direction unless cmp == 0
          end

          0
        end

        def nil_aware_compare(a, b)
          return 0 if a.nil? && b.nil?
          return -1 if a.nil?
          return 1 if b.nil?
          0
        end

        def dig_field(hash, field_name)
          field_name.split(".").reduce(hash) { |obj, key| obj.is_a?(Hash) ? obj[key] : nil }
        end

        def sort_random(input_items)
          input_items.shuffle
        end

        def sort_code(exec_ctx, config)
          code = config["code"].to_s
          unless code.match?(/\breturn\b/)
            raise_node_error!(I18n.t("discourse_workflows.errors.sort.code_missing_return"))
          end

          items = exec_ctx.input_items.map(&:deep_dup)
          execution_result =
            exec_ctx.start_job(
              "javascript",
              {
                code: "return items.sort(function(a, b) { #{code} });",
                nodeMode: RUN_CODE,
                workflowMode: exec_ctx.get_mode,
                continueOnFail: exec_ctx.continue_on_fail,
                additionalProperties: {
                  "items" => items,
                },
              },
              0,
            )

          raise execution_result.error if execution_result.error.is_a?(Exception)
          unless execution_result.ok
            raise_node_error!(
              I18n.t("discourse_workflows.errors.javascript_execution_failed"),
              description: execution_result.error.to_s,
            )
          end

          execution_result.result
        end
      end
    end
  end
end
