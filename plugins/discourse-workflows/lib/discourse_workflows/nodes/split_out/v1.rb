# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SplitOut
      class V1 < NodeType
        MAX_SPLIT_ITEMS = 1_000

        description(
          name: "action:split_out",
          version: "1.0",
          defaults: {
            icon: "arrows-turn-to-dots",
            color: "yellow",
          },
          group: "flow",
          palette_visible: false,
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            field: {
              type: :string,
              required: true,
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
          },
        )

        def execute(exec_ctx)
          field_tracker = {}
          items =
            exec_ctx.input_items.flat_map.with_index do |item, item_index|
              config =
                split_config(
                  {
                    "field" => exec_ctx.get_node_parameter("field", item_index),
                    "include" =>
                      exec_ctx.get_node_parameter(
                        "include",
                        item_index,
                        default: "no_other_fields",
                      ),
                    "fields_to_include" =>
                      exec_ctx.get_node_parameter("fields_to_include", item_index),
                    "destination_field_name" =>
                      exec_ctx.get_node_parameter("destination_field_name", item_index),
                  },
                )

              split_item(item, config, exec_ctx.paired_item_for(item), field_tracker)
            end

          add_missing_field_hints(exec_ctx, field_tracker)

          [items]
        end

        private

        def split_config(config)
          field_names = parse_field_names(config["field"])
          dest_names = parse_field_names(config["destination_field_name"])

          if dest_names.present? && dest_names.length != field_names.length
            raise_node_error!(
              I18n.t("discourse_workflows.errors.split_out.destination_count_mismatch"),
            )
          end

          {
            field_names: field_names,
            include_mode: config.fetch("include") { "no_other_fields" },
            dest_names: dest_names,
            fields_to_include: parse_field_names(config["fields_to_include"]),
          }
        end

        def parse_field_names(value)
          return [] if value.blank?
          value.to_s.split(",").filter_map { |v| v.strip.sub(/\A\$json\./, "").presence }
        end

        def fetch_field(hash, field_name)
          current = hash
          field_name
            .split(".")
            .each do |key|
              return false, nil unless current.is_a?(Hash) && current.key?(key)

              current = current[key]
            end

          [true, current]
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
          return value if value.is_a?(Array)
          return value.values if value.is_a?(Hash)

          [value]
        end

        def split_item(item, config, paired_item, field_tracker)
          item_json = item.fetch("json") { {} }
          field_names = config[:field_names]
          multi_split = field_names.length > 1
          entries = []

          field_names.each_with_index do |field_name, field_index|
            field_tracker[field_name] = false unless field_tracker.key?(field_name)
            exists, value = fetch_field(item_json, field_name)
            field_tracker[field_name] = true if exists
            next unless exists

            elements = coerce_to_array(value)

            next if elements.empty?

            if elements.length > MAX_SPLIT_ITEMS
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.split_out.too_many_items",
                  max: MAX_SPLIT_ITEMS,
                  count: elements.length,
                ),
              )
            end

            elements.each_with_index do |element, element_index|
              entries[element_index] ||= { "json" => {} }
              write_split_element(
                entries[element_index]["json"],
                element,
                field_name,
                config[:dest_names][field_index],
                config[:include_mode],
                multi_split,
              )
            end
          end

          entries.map do |entry|
            json =
              apply_include_mode(
                entry["json"],
                item_json,
                config[:include_mode],
                field_names,
                config[:fields_to_include],
              )
            wrap(json, paired_item:)
          end
        end

        def write_split_element(
          entry,
          element,
          field_name,
          destination_field_name,
          include_mode,
          multi_split
        )
          output_field_name = destination_field_name.presence || field_name

          if element.is_a?(Hash) && include_mode == "no_other_fields" &&
               destination_field_name.blank? && !multi_split
            entry.merge!(element.deep_stringify_keys)
          else
            entry[output_field_name] = element
          end
        end

        def apply_include_mode(entry, item_json, include_mode, field_names, fields_to_include)
          case include_mode
          when "all_other_fields"
            base = item_json.deep_dup
            field_names.each { |f| unset_field(base, f) }
            base.merge(entry)
          when "selected_other_fields"
            if fields_to_include.empty?
              raise_node_error!(
                I18n.t("discourse_workflows.errors.split_out.fields_to_include_required"),
              )
            end

            fields_to_include.each do |f|
              _, val = fetch_field(item_json, f)
              entry[f] = val
            end
            entry
          else
            entry
          end
        end

        def add_missing_field_hints(exec_ctx, field_tracker)
          field_tracker.each do |field, found|
            next if found

            exec_ctx.add_execution_hints(
              {
                message:
                  I18n.t("discourse_workflows.hints.split_out.field_not_found", field: field),
                location: "outputPane",
              },
            )
          end
        end
      end
    end
  end
end
