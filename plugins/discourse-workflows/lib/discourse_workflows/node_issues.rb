# frozen_string_literal: true

module DiscourseWorkflows
  class NodeIssues
    class << self
      def for_node(node, node_type_class, guardian: nil)
        return [] unless node_type_class.respond_to?(:property_schema)
        schema = node_type_class.property_schema || {}
        config = NodeData.resolved_parameters(node)
        preloaded_options = nil
        metadata =
          Hash.new do |_, collection|
            preloaded_options ||=
              PreloadedOptions.for(node_type_class, guardian:, properties: schema)
            preloaded_options[collection]
          end
        walk(schema, config.deep_stringify_keys, "", metadata)
      end

      private

      def walk(schema, config, path_prefix, metadata)
        effective = apply_defaults(schema, config)
        issues = []

        schema.each do |name, field|
          if !field[:required] &&
               %i[collection fixed_collection assignment_collection].exclude?(field[:type])
            next
          end
          next unless field_definitely_visible?(field, effective, metadata)

          name_s = name.to_s
          path = path_prefix.empty? ? name_s : "#{path_prefix}.#{name_s}"
          value = effective[name_s]

          if field[:required] && blank_value?(value)
            issues << { path: path, name: name_s, message: "required" }
          end

          case field[:type]
          when :collection
            if value.is_a?(Hash)
              field[:options].to_a.each do |option|
                option_name = option[:name].to_s
                next unless value.key?(option_name)

                option_schema = { option_name => option.except(:name, :display_name) }
                issues.concat(walk(option_schema, value, path, metadata))
              end
            elsif value.is_a?(Array)
              item_schema = (field[:item_schema] || {}).merge(field[:extra_item_schema] || {})
              value.each_with_index do |item, index|
                item_hash = item.is_a?(Hash) ? item.deep_stringify_keys : {}
                issues.concat(walk(item_schema, item_hash, "#{path}.#{index}", metadata))
              end
            end
          when :fixed_collection
            field[:options].to_a.each do |group|
              group_name = group[:name].to_s
              rows = CollectionParameters.rows_from_value(value, group: group_name)
              if field[:required] && !blank_value?(value) && blank_value?(rows)
                issues << { path: "#{path}.#{group_name}", name: name_s, message: "required" }
              end

              rows.each_with_index do |item, index|
                item_hash = item.is_a?(Hash) ? item.deep_stringify_keys : {}
                issues.concat(
                  walk(group[:values] || {}, item_hash, "#{path}.#{group_name}.#{index}", metadata),
                )
              end
            end
          when :assignment_collection
            assignments = CollectionParameters.rows_from_value(value, group: "assignments")
            if field[:required] && !blank_value?(value) && blank_value?(assignments)
              issues << { path: "#{path}.assignments", name: name_s, message: "required" }
            end

            assignment_schema = {
              name: {
                type: :string,
                required: true,
              },
              type: {
                type: :options,
                required: true,
              },
              value: {
                type: :string,
                required: true,
              },
            }

            assignments.each_with_index do |item, index|
              item_hash = item.is_a?(Hash) ? item.deep_stringify_keys : {}
              issues.concat(
                walk(assignment_schema, item_hash, "#{path}.assignments.#{index}", metadata),
              )
            end
          end
        end
        issues
      end

      def apply_defaults(schema, config)
        result = config.dup
        schema.each do |name, field|
          name_s = name.to_s
          result[name_s] = field[:default] if result[name_s].nil? && !field[:default].nil?
        end
        result
      end

      def field_definitely_visible?(field, config, metadata)
        return false if (field[:ui] || {})[:hidden]

        Schema.definitely_visible?(field[:display_options] || {}, config, metadata)
      end

      def blank_value?(value)
        return true if value.nil?
        return value.strip.empty? if value.is_a?(String)
        return value.empty? if value.is_a?(Array)
        false
      end
    end
  end
end
