# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SetFields
      class V1 < NodeType
        description(
          name: "action:set_fields",
          version: "1.0",
          defaults: {
            icon: "list",
            color: "green",
          },
          group: "data",
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            mode: {
              type: :options,
              required: false,
              options: %w[manual raw],
              default: "manual",
            },
            assignments: {
              type: :assignment_collection,
              required: false,
              default: {
                assignments: [],
              },
              type_options: {
                assignment_types: %w[string number boolean array object],
              },
              display_options: {
                show: {
                  mode: ["manual"],
                },
              },
            },
            json_output: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  mode: ["raw"],
                },
              },
              no_data_expression: true,
              ui: {
                control: :code,
              },
              control_options: {
                height: 200,
                lang: :json,
              },
            },
            include_other_fields: {
              type: :boolean,
              required: false,
              default: true,
            },
            include: {
              type: :options,
              required: false,
              options: %w[all selected except],
              default: "all",
              display_options: {
                show: {
                  include_other_fields: [true],
                },
              },
            },
            include_fields: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  include_other_fields: [true],
                  include: ["selected"],
                },
              },
            },
            exclude_fields: {
              type: :string,
              required: false,
              display_options: {
                show: {
                  include_other_fields: [true],
                  include: ["except"],
                },
              },
            },
            options: {
              type: :collection,
              required: false,
              options: [
                { name: "dot_notation", type: :boolean, default: true },
                { name: "ignore_conversion_errors", type: :boolean, default: false },
              ],
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |item, item_index|
              config = {
                "mode" => exec_ctx.get_node_parameter("mode", item_index, default: "manual"),
                "json_output" => exec_ctx.get_node_parameter("json_output", item_index),
                "include_other_fields" =>
                  exec_ctx.get_node_parameter("include_other_fields", item_index, default: true),
                "include" => exec_ctx.get_node_parameter("include", item_index, default: "all"),
                "include_fields" => exec_ctx.get_node_parameter("include_fields", item_index),
                "exclude_fields" => exec_ctx.get_node_parameter("exclude_fields", item_index),
              }

              wrap(process(exec_ctx, item, item_index, config))
            end

          [items]
        end

        private

        def process(exec_ctx, item, item_index, config)
          item_json = item.fetch("json") { {} }
          options = exec_ctx.get_node_parameter("options", item_index, default: {})
          result = included_fields(item_json, config, options)

          if config["mode"] == "raw"
            result.merge(parse_json_fields(config))
          else
            apply_assignments(
              result,
              exec_ctx.get_node_parameter("assignments.assignments", item_index, default: []),
              options,
            )
          end
        end

        def included_fields(item_json, config, options)
          return {} unless config.fetch("include_other_fields", true)

          dot_notation = dot_notation?(options)
          fields =
            case config.fetch("include") { "all" }
            when "selected"
              selected_fields(item_json, config["include_fields"], dot_notation)
            when "except"
              except_fields(item_json, config["exclude_fields"], dot_notation)
            else
              item_json.deep_dup
            end

          fields || {}
        end

        def parse_json_fields(config)
          raw_json = config["json_output"]
          if raw_json.blank?
            raise_node_error!(I18n.t("discourse_workflows.errors.set_fields.json_blank"))
          end

          parsed = JSON.parse(raw_json)
          unless parsed.is_a?(Hash)
            raise_node_error!(I18n.t("discourse_workflows.errors.set_fields.json_must_be_object"))
          end

          parsed
        rescue JSON::ParserError => e
          raise_node_error!("Invalid JSON", description: e.message)
        end

        def apply_assignments(result, assignments, options)
          dot_notation = dot_notation?(options)
          ignore_errors = options.fetch("ignore_conversion_errors", false)

          assignments.each do |field|
            key = field["name"].to_s
            next if key.blank?

            value = cast_value(field["value"], field.fetch("type") { "string" }, ignore_errors)
            set_field(result, key, value, dot_notation)
          end

          result
        end

        def selected_fields(item_json, field_list, dot_notation)
          split_fields(field_list).each_with_object({}) do |field, result|
            value = get_field(item_json, field, dot_notation)
            next if value.nil?

            output_field = dot_notation && field.include?(".") ? field.split(".").last : field
            set_field(result, output_field, value, dot_notation)
          end
        end

        def except_fields(item_json, field_list, dot_notation)
          result = item_json.deep_dup
          split_fields(field_list).each { |field| unset_field(result, field, dot_notation) }
          result
        end

        def split_fields(field_list)
          field_list.to_s.split(",").map(&:strip).reject(&:blank?)
        end

        def dot_notation?(options)
          options.fetch("dot_notation", true)
        end

        def cast_value(value, type, ignore_errors)
          cast_value!(value, type, ignore_errors)
        rescue JSON::ParserError, ArgumentError => e
          return value if ignore_errors

          raise_node_error!("Invalid field value", description: e.message)
        end

        def cast_value!(value, type, ignore_errors)
          case type
          when "integer"
            Integer(value)
          when "float"
            Float(value)
          when "number"
            Float(value)
          when "boolean"
            return value if value == true || value == false

            %w[true 1].include?(value.to_s.downcase)
          when "array"
            cast_json_value(value, Array, ignore_errors)
          when "object"
            cast_json_value(value, Hash, ignore_errors)
          else
            value.to_s
          end
        end

        def cast_json_value(value, expected_class, ignore_errors)
          return value if value.is_a?(expected_class)

          parsed = JSON.parse(value.to_s)
          return parsed if parsed.is_a?(expected_class)
          return value if ignore_errors

          expected_type = expected_class == Array ? "array" : "object"
          raise_node_error!("Invalid field value", description: "Expected #{expected_type}")
        end

        def set_field(result, field, value, dot_notation)
          unless dot_notation && field.include?(".")
            result[field] = value
            return
          end

          keys = field.split(".")
          leaf = keys.pop
          target = result
          keys.each do |key|
            target[key] = {} unless target[key].is_a?(Hash)
            target = target[key]
          end
          target[leaf] = value
        end

        def get_field(hash, field, dot_notation)
          return hash[field] unless dot_notation && field.include?(".")

          field.split(".").reduce(hash) { |value, key| value.is_a?(Hash) ? value[key] : nil }
        end

        def unset_field(hash, field, dot_notation)
          unless dot_notation && field.include?(".")
            hash.delete(field)
            return
          end

          keys = field.split(".")
          leaf = keys.pop
          target = keys.reduce(hash) { |value, key| value.is_a?(Hash) ? value[key] : nil }
          target.delete(leaf) if target.is_a?(Hash)
        end
      end
    end
  end
end
