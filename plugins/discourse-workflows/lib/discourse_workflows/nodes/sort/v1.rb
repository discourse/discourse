# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Sort
      class V1 < NodeType
        def self.identifier
          "action:sort"
        end

        def self.icon
          "arrow-down-a-z"
        end

        def self.color
          "yellow"
        end

        def self.group
          "flow"
        end

        def self.property_schema
          {
            type: {
              type: :options,
              required: true,
              options: %w[simple random code],
              default: "simple",
            },
            sort_fields: {
              type: :collection,
              required: false,
              visible_if: {
                type: "simple",
              },
              item_schema: {
                field_name: {
                  type: :string,
                  required: true,
                  ui: {
                    expression: false,
                  },
                },
                order: {
                  type: :options,
                  required: true,
                  options: %w[ascending descending],
                  default: "ascending",
                },
              },
            },
            code: {
              type: :string,
              required: false,
              visible_if: {
                type: "code",
              },
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
                expression: false,
                height: 200,
                lang: :javascript,
              },
            },
          }
        end

        def self.output_schema
          {}
        end

        def execute(exec_ctx)
          type = @configuration.fetch("type") { "simple" }

          items =
            case type
            when "simple"
              sort_simple(exec_ctx.input_items)
            when "random"
              sort_random(exec_ctx.input_items)
            when "code"
              sort_code(exec_ctx)
            else
              exec_ctx.input_items.dup
            end
          [items]
        end

        private

        def sort_simple(input_items)
          sort_fields = @configuration["sort_fields"]
          return input_items.dup if sort_fields.blank?

          input_items.sort { |a, b| compare_items(a, b, sort_fields) }
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

        def sort_code(exec_ctx)
          code = @configuration["code"].to_s
          unless code.match?(/\breturn\b/)
            raise ArgumentError, "Code must contain a return statement"
          end

          items = exec_ctx.input_items.map { |item| { "json" => item.fetch("json") { {} } } }
          sorted =
            exec_ctx.with_sandbox(capture_logs: true) do |sandbox|
              sandbox.eval("var __items = #{items.to_json};")
              sandbox.eval("(function() { return __items.sort(function(a, b) { #{code} }); })()")
            end

          sorted.map { |item| Item.new(item.fetch("json") { {} }).to_h }
        end
      end
    end
  end
end
