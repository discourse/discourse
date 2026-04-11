# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SplitOut
      class V1 < NodeType
        def self.identifier
          "action:split_out"
        end

        def self.icon
          "arrows-turn-to-dots"
        end

        def self.color
          "yellow"
        end

        def self.group
          "flow"
        end

        def self.property_schema
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

        def execute(exec_ctx)
          field_names = parse_field_names(@configuration.fetch("field"))
          include_mode = @configuration.fetch("include") { "no_other_fields" }
          dest_names = parse_field_names(@configuration["destination_field_name"])
          fields_to_include = parse_field_names(@configuration["fields_to_include"])

          if dest_names.present? && dest_names.length != field_names.length
            raise ArgumentError, "destination_field_name count must match field count"
          end

          items =
            exec_ctx.input_items.flat_map do |item|
              split_item(item, field_names, include_mode, dest_names, fields_to_include)
            end
          [items]
        end

        private

        def parse_field_names(value)
          return [] if value.blank?
          value.to_s.split(",").filter_map { |v| v.strip.presence }
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
          return nil if value.nil?
          value = value.values if value.is_a?(Hash)
          Array(value)
        end

        def split_item(item, field_names, include_mode, dest_names, fields_to_include)
          item_json = item.fetch("json") { {} }
          arrays = field_names.map { |f| coerce_to_array(dig_field(item_json, f)) }

          return [item] if arrays.any?(&:nil?)

          max_len = arrays.map(&:length).max || 0
          return [item] if max_len == 0

          (0...max_len).map do |i|
            entry = build_split_entry(i, field_names, arrays, dest_names)
            entry =
              apply_include_mode(entry, item_json, include_mode, field_names, fields_to_include)
            Item.new(entry).to_h
          end
        end

        def build_split_entry(index, field_names, arrays, dest_names)
          entry = {}
          field_names.each_with_index do |field_name, fi|
            element = arrays[fi][index]

            if field_names.length == 1 && dest_names.blank?
              element.is_a?(Hash) ?
                entry.merge!(element.deep_stringify_keys) :
                entry["value"] = element
            else
              set_field(entry, dest_names.present? ? dest_names[fi] : field_name, element)
            end
          end
          entry
        end

        def apply_include_mode(entry, item_json, include_mode, field_names, fields_to_include)
          case include_mode
          when "all_other_fields"
            base = item_json.deep_dup
            field_names.each { |f| unset_field(base, f) }
            base.merge(entry)
          when "selected_other_fields"
            fields_to_include.each do |f|
              val = dig_field(item_json, f)
              set_field(entry, f, val) unless val.nil?
            end
            entry
          else
            entry
          end
        end
      end
    end
  end
end
