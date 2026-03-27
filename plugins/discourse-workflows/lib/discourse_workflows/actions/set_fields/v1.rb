# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module SetFields
      class V1 < Actions::Base
        def self.identifier
          "action:set_fields"
        end

        def self.icon
          "list"
        end

        def self.color_key
          "green"
        end

        def self.configuration_schema
          {
            include_input: {
              type: :boolean,
              required: false,
              default: true,
            },
            mode: {
              type: :options,
              required: false,
              options: %w[manual json],
              default: "manual",
            },
            fields: {
              type: :collection,
              required: false,
              item_schema: {
                key: {
                  type: :string,
                  required: true,
                  ui: {
                    expression: false,
                  },
                },
                type: {
                  type: :options,
                  required: true,
                  options: %w[string integer boolean],
                },
                value: {
                  type: :string,
                  required: true,
                },
              },
              visible_if: {
                mode: "manual",
              },
            },
            json: {
              type: :string,
              required: false,
              visible_if: {
                mode: "json",
              },
              ui: {
                control: :code,
                expression: false,
                height: 200,
                lang: :json,
              },
            },
          }
        end

        def self.output_schema
          {}
        end

        def execute_single(context, item:, config:)
          item_json = item["json"] || {}

          result =
            if config["mode"] == "json"
              parse_json_fields(config)
            else
              parse_manual_fields(config)
            end

          if config.fetch("include_input", true)
            item_json.merge(result)
          else
            result
          end
        end

        private

        def parse_manual_fields(config)
          (config["fields"] || []).each_with_object({}) do |field, result|
            key = field["key"].to_s
            next if key.blank?

            result[key] = cast_value(field["value"], field["type"] || "string")
          end
        end

        def parse_json_fields(config)
          raw_json = config["json"]
          raise ArgumentError, "JSON string is blank" if raw_json.blank?

          parsed = JSON.parse(raw_json)
          raise ArgumentError, "JSON must be an object" unless parsed.is_a?(Hash)

          parsed
        end

        def cast_value(value, type)
          case type
          when "integer"
            Integer(value)
          when "boolean"
            %w[true 1].include?(value.to_s.downcase)
          else
            value.to_s
          end
        end
      end
    end
  end
end
