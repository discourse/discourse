# frozen_string_literal: true

module DiscourseWorkflows
  class NodeIssues
    def self.for_node(node, node_type_class)
      return [] unless node_type_class.respond_to?(:property_schema)
      schema = node_type_class.property_schema || {}
      config = (node.respond_to?(:configuration) ? node.configuration : node["configuration"]) || {}
      new.walk(schema, config.deep_stringify_keys, "")
    end

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

        if field[:type] == :collection && value.is_a?(Array)
          item_schema = (field[:item_schema] || {}).merge(field[:extra_item_schema] || {})
          value.each_with_index do |item, index|
            item_hash = item.is_a?(Hash) ? item.deep_stringify_keys : {}
            issues.concat(walk(item_schema, item_hash, "#{path}.#{index}"))
          end
        end
      end
      issues
    end

    private

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
      return false if field[:visible_if] && !matches_rules?(field[:visible_if], config)
      return false if field[:visible_unless] && matches_rules?(field[:visible_unless], config)
      true
    end

    def matches_rules?(rules, config)
      rules.all? { |field_name, expected| matches_rule?(expected, config[field_name.to_s]) }
    end

    def matches_rule?(expected, value)
      return empty_value?(value) if expected == "$empty"

      if expected.is_a?(Hash)
        if expected.key?(:empty)
          return expected[:empty] ? empty_value?(value) : !empty_value?(value)
        end
        if expected.key?(:not)
          not_values = Array(expected[:not])
          return !not_values.include?(value)
        end
        return false
      end

      Array(expected).include?(value)
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
