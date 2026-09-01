# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Summarize
      class V1 < NodeType
        AGGREGATIONS = %w[
          append
          average
          collect
          concatenate
          count
          count_unique
          first
          last
          max
          min
          sum
          unique
        ].freeze

        OUTPUT_PREFIXES = {
          "append" => "appended_",
          "average" => "average_",
          "collect" => "collected_",
          "concatenate" => "concatenated_",
          "count" => "count_",
          "count_unique" => "unique_count_",
          "first" => "first_",
          "last" => "last_",
          "max" => "max_",
          "min" => "min_",
          "sum" => "sum_",
          "unique" => "unique_",
        }.freeze

        SEPARATORS = {
          "comma" => ",",
          "comma_space" => ", ",
          "space" => " ",
          "newline" => "\n",
          "none" => "",
        }.freeze
        SEPARATOR_OPTIONS = (SEPARATORS.keys + ["custom"]).freeze

        NUMBER_TYPE = { "type" => %w[number null] }.freeze
        INTEGER_TYPE = { "type" => "integer" }.freeze
        STRING_TYPE = { "type" => "string" }.freeze
        ARRAY_TYPE = { "type" => "array" }.freeze
        ANY_TYPE = {}.freeze

        description(
          name: "action:summarize",
          version: "1.0",
          defaults: {
            icon: "layer-group",
            color: "yellow",
          },
          group: "data",
          previewable: true,
          output_schema_resolver: "summarize",
          capabilities: {
            run_scope: "all_items",
          },
          properties: {
            fields_to_split_by: {
              type: :string,
              required: false,
              no_data_expression: true,
              ui: {
                control: :field_path,
                multiple: true,
              },
              control_options: {
                none_label_i18n_key: "discourse_workflows.summarize.group_by_none",
              },
            },
            fields_to_summarize: {
              type: :fixed_collection,
              required: true,
              ui: {
                control: :summarize_aggregations,
              },
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
                    aggregation: {
                      type: :options,
                      required: true,
                      options: AGGREGATIONS,
                      default: "count",
                      no_data_expression: true,
                    },
                    field: {
                      type: :string,
                      required: false,
                      no_data_expression: true,
                      ui: {
                        control: :field_path,
                      },
                    },
                    output_field_name: {
                      type: :string,
                      required: false,
                      no_data_expression: true,
                    },
                    separate_by: {
                      type: :options,
                      required: false,
                      options: SEPARATOR_OPTIONS,
                      default: "comma_space",
                      no_data_expression: true,
                      display_options: {
                        show: {
                          aggregation: ["concatenate"],
                        },
                      },
                    },
                    custom_separator: {
                      type: :string,
                      required: false,
                      no_data_expression: true,
                      display_options: {
                        show: {
                          separate_by: ["custom"],
                        },
                      },
                    },
                  },
                },
              ],
            },
          },
        )

        # The output keys depend on how the node is configured, so the contract is derived
        # from the configuration rather than declared as a constant.
        class << self
          def output_schemas(configuration = {}, input_schemas: [])
            config = (configuration || {}).deep_stringify_keys
            rows = Array(config.dig("fields_to_summarize", "values"))
            split_fields = split_field_list(config["fields_to_split_by"])

            properties = {}
            split_fields.each { |field| properties[leaf_name(field)] = ANY_TYPE }
            rows.each { |row| properties[output_key(row)] = schema_type_for(row) }

            [Schema.document(properties)]
          end

          def split_field_list(value)
            value.to_s.split(",").filter_map { |field| field.strip.presence }
          end

          def leaf_name(field)
            return field if field.exclude?(".")
            field.split(".").last
          end

          def output_key(row)
            row = row.deep_stringify_keys
            explicit = row["output_field_name"].to_s.strip
            return explicit if explicit.present?

            prefix = OUTPUT_PREFIXES.fetch(row["aggregation"].to_s, "")
            field = row["field"].to_s.strip
            return prefix.chomp("_") if field.empty?

            "#{prefix}#{sanitize_key(leaf_name(field))}"
          end

          def sanitize_key(name)
            name.to_s.gsub(/["\[\]]/, "").gsub(/[ .]/, "_")
          end

          def schema_type_for(row)
            case row.deep_stringify_keys["aggregation"].to_s
            when "count", "count_unique"
              INTEGER_TYPE
            when "sum", "average"
              NUMBER_TYPE
            when "concatenate"
              STRING_TYPE
            when "append", "collect", "unique"
              ARRAY_TYPE
            else
              ANY_TYPE
            end
          end
        end

        def execute(exec_ctx)
          split_fields =
            self.class.split_field_list(
              exec_ctx.get_node_parameter("fields_to_split_by", 0, default: ""),
            )
          rows = normalized_rows(exec_ctx)
          groups = group_items(exec_ctx.input_items, split_fields)

          [separate_items(groups, split_fields, rows, exec_ctx)]
        end

        private

        def normalized_rows(exec_ctx)
          rows =
            Array(exec_ctx.get_node_parameter("fields_to_summarize.values", 0, default: [])).map(
              &:deep_stringify_keys
            )

          if rows.empty?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.summarize.no_aggregations"),
              description: I18n.t("discourse_workflows.errors.summarize.no_aggregations_help"),
            )
          end

          rows.each { |row| validate_aggregation!(row) }
          validate_unique_output_keys!(rows)
          rows
        end

        def validate_aggregation!(row)
          aggregation = row["aggregation"].to_s
          return if AGGREGATIONS.include?(aggregation)

          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.summarize.invalid_aggregation",
              aggregation: aggregation,
            ),
          )
        end

        def validate_unique_output_keys!(rows)
          keys = rows.map { |row| self.class.output_key(row) }
          duplicate = keys.tally.find { |_key, count| count > 1 }&.first
          return if duplicate.nil?

          raise_node_error!(
            I18n.t("discourse_workflows.errors.summarize.duplicate_output_field", field: duplicate),
            description: I18n.t("discourse_workflows.errors.summarize.duplicate_output_field_help"),
          )
        end

        def group_items(input_items, split_fields)
          return [{ keys: [], items: input_items }] if split_fields.empty?

          input_items
            .group_by { |item| split_fields.map { |field| dig_field(item_json(item), field) } }
            .map { |keys, items| { keys: keys, items: items } }
        end

        def separate_items(groups, split_fields, rows, exec_ctx)
          groups.map do |group|
            json = {}

            split_fields.each_with_index do |field, index|
              json[self.class.leaf_name(field)] = group[:keys][index]
            end

            json.merge!(aggregate(group[:items], rows))

            wrap(json, paired_item: paired_items_for(group[:items], exec_ctx))
          end
        end

        def aggregate(items, rows)
          rows.each_with_object({}) do |row, result|
            result[self.class.output_key(row)] = compute(row, items)
          end
        end

        def compute(row, items)
          field = row["field"].to_s.strip

          case row["aggregation"].to_s
          when "count"
            return items.length if field.empty?
            values(items, field).length
          when "count_unique"
            unique_values(items, field).length
          when "unique"
            unique_values(items, field)
          when "append"
            values(items, field)
          when "collect"
            return items.map { |item| item_json(item) } if field.empty?
            values(items, field)
          when "concatenate"
            values(items, field).map { |value| cell(value) }.join(separator(row))
          when "first"
            values(items, field).first
          when "last"
            values(items, field).last
          when "sum"
            numeric_values(items, field).sum
          when "average"
            numbers = numeric_values(items, field)
            return nil if numbers.empty?
            numbers.sum.to_f / numbers.length
          when "min"
            comparable_values(items, field).min
          when "max"
            comparable_values(items, field).max
          end
        end

        def values(items, field)
          items.filter_map do |item|
            value = dig_field(item_json(item), field)
            value unless empty_value?(value)
          end
        end

        # Array-valued fields are flattened so that, for example, per-post tag arrays
        # collapse into the set of tags used across a group.
        def unique_values(items, field)
          items
            .flat_map do |item|
              value = dig_field(item_json(item), field)
              value.is_a?(Array) ? value : [value]
            end
            .reject { |value| empty_value?(value) }
            .uniq
        end

        def numeric_values(items, field)
          items.filter_map { |item| numeric(dig_field(item_json(item), field)) }
        end

        def comparable_values(items, field)
          raw = values(items, field)
          return [] if raw.empty?

          numbers = raw.map { |value| numeric(value) }
          return numbers if numbers.none?(&:nil?)

          raw.map(&:to_s)
        end

        def numeric(value)
          case value
          when Numeric
            value
          when String
            Float(value)
          end
        rescue ArgumentError, TypeError
          nil
        end

        def separator(row)
          key = row["separate_by"].to_s
          return row["custom_separator"].to_s if key == "custom"
          SEPARATORS.fetch(key, ", ")
        end

        def cell(value)
          value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value.to_s
        end

        def empty_value?(value)
          return true if value.nil?
          return value.empty? if value.respond_to?(:empty?)
          false
        end

        def item_json(item)
          item.fetch("json") { {} }
        end

        def dig_field(json, field)
          field.split(".").reduce(json) { |value, key| value.is_a?(Hash) ? value[key] : nil }
        end

        def paired_items_for(items, exec_ctx)
          items.map { |item| exec_ctx.paired_item_for(item) }
        end
      end
    end
  end
end
