# frozen_string_literal: true

module DiscourseWorkflows
  class NodeIssues
    class << self
      def for_node(node, node_type_class)
        return [] unless node_type_class.respond_to?(:property_schema)
        schema = node_type_class.property_schema || {}
        config = NodeData.resolved_parameters(node)
        walk(schema, config.deep_stringify_keys, "")
      end

      private

      def walk(schema, config, path_prefix)
        effective = apply_defaults(schema, config)
        issues = []

        schema.each do |name, field|
          next unless field_visible?(field, effective)

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
                issues.concat(walk(option_schema, value, path))
              end
            elsif value.is_a?(Array)
              item_schema = (field[:item_schema] || {}).merge(field[:extra_item_schema] || {})
              value.each_with_index do |item, index|
                item_hash = item.is_a?(Hash) ? item.deep_stringify_keys : {}
                issues.concat(walk(item_schema, item_hash, "#{path}.#{index}"))
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
                  walk(group[:values] || {}, item_hash, "#{path}.#{group_name}.#{index}"),
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
              issues.concat(walk(assignment_schema, item_hash, "#{path}.assignments.#{index}"))
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

      def field_visible?(field, config)
        ui = field[:ui] || {}
        return false if ui[:hidden]
        display_options = field[:display_options] || {}
        return false if display_options[:show] && !matches_rules?(display_options[:show], config)
        return false if display_options[:hide] && matches_rules?(display_options[:hide], config)
        true
      end

      def matches_rules?(rules, config)
        rules.all? { |field_name, expected| matches_rule?(expected, config[field_name.to_s]) }
      end

      def matches_rule?(expected, value)
        return false unless expected.is_a?(Array)

        expected.any? { |condition| matches_condition?(condition, value) }
      end

      def matches_condition?(condition, value)
        operator = condition.is_a?(Hash) ? condition[:condition] || condition["condition"] : nil
        return condition == value if operator.blank?

        if operator.key?(:not) || operator.key?("not")
          expected = operator.key?(:not) ? operator[:not] : operator["not"]
          return value != expected
        end

        if operator.key?(:exists) || operator.key?("exists")
          exists = operator.key?(:exists) ? operator[:exists] : operator["exists"]
          return exists ? !empty_value?(value) : empty_value?(value)
        end

        false
      end

      def empty_value?(value)
        return true if value.nil? || value == ""
        return value.empty? if value.is_a?(Array)
        false
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
