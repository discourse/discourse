# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module SplitOut
      class V1 < Actions::Base
        def self.identifier
          "action:split_out"
        end

        def self.icon
          "arrows-turn-to-dots"
        end

        def self.color_key
          "yellow"
        end

        def self.configuration_schema
          {
            field: {
              type: :string,
              required: true,
              ui: {
                expression: false,
              },
            },
            include: {
              type: :options,
              required: false,
              options: %w[no_other_fields all_other_fields selected_other_fields],
              default: "no_other_fields",
              ui: {
                expression: true,
              },
            },
            fields_to_include: {
              type: :string,
              required: false,
            },
            destination_field_name: {
              type: :string,
              required: false,
            },
          }
        end

        def self.output_schema
          {}
        end

        def execute(context, input_items:, node_context:, user: nil)
          field_names = parse_field_names(@configuration["field"])
          include_mode = @configuration["include"] || "no_other_fields"
          dest_names = parse_field_names(@configuration["destination_field_name"])
          fields_to_include = parse_field_names(@configuration["fields_to_include"])

          if dest_names.present? && dest_names.length != field_names.length
            raise ArgumentError, "destination_field_name count must match field count"
          end

          input_items.flat_map do |item|
            split_item(item, field_names, include_mode, dest_names, fields_to_include)
          end
        end

        private

        def parse_field_names(value)
          return [] if value.blank?
          value.to_s.split(",").map(&:strip).reject(&:blank?)
        end

        def dig_field(hash, field_name)
          field_name.split(".").reduce(hash) { |obj, key| obj.is_a?(Hash) ? obj[key] : nil }
        end

        def set_field(hash, field_name, value)
          keys = field_name.split(".")
          current = hash
          keys[0..-2].each do |key|
            current[key] ||= {}
            current = current[key]
          end
          current[keys.last] = value
        end

        def unset_field(hash, field_name)
          keys = field_name.split(".")
          current = hash
          keys[0..-2].each do |key|
            current = current.is_a?(Hash) ? current[key] : nil
            break unless current
          end
          current.delete(keys.last) if current.is_a?(Hash)
        end

        def coerce_to_array(value)
          if value.is_a?(Array)
            value
          elsif value.is_a?(Hash)
            value.values
          elsif value.nil?
            nil
          else
            [value]
          end
        end

        def split_item(item, field_names, include_mode, dest_names, fields_to_include)
          item_json = item["json"] || {}

          arrays = field_names.map { |f| coerce_to_array(dig_field(item_json, f)) }

          return [item] if arrays.any?(&:nil?)

          max_len = arrays.map(&:length).max || 0
          return [item] if max_len == 0

          (0...max_len).map do |i|
            entry = {}

            field_names.each_with_index do |field_name, fi|
              element = arrays[fi][i]

              if field_names.length == 1 && dest_names.blank?
                if element.is_a?(Hash)
                  entry.merge!(element.deep_stringify_keys)
                else
                  entry["value"] = element
                end
              else
                dest = dest_names.present? ? dest_names[fi] : field_name
                set_field(entry, dest, element)
              end
            end

            case include_mode
            when "all_other_fields"
              base = item_json.deep_dup
              field_names.each { |f| unset_field(base, f) }
              entry = base.merge(entry)
            when "selected_other_fields"
              fields_to_include.each do |f|
                val = dig_field(item_json, f)
                set_field(entry, f, val) unless val.nil?
              end
            end

            { "json" => entry.deep_stringify_keys }
          end
        end
      end
    end
  end
end
