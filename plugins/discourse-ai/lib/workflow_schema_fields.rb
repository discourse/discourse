# frozen_string_literal: true

module DiscourseAi
  module WorkflowSchemaFields
    class << self
      def convert(schema)
        schema = effective(normalize(schema))
        return {} unless object_schema?(schema)

        flatten_properties(schema["properties"], nil, {})
      end

      private

      def flatten_properties(properties, parent_path, result)
        properties.each do |name, property_schema|
          flatten_property(
            effective(normalize(property_schema)),
            property_path(parent_path, name),
            result,
          )
        end

        result
      end

      def flatten_property(schema, path, result)
        if schema.key?("const")
          result[path] = JSON.generate(schema["const"])
        elsif object_schema?(schema)
          result[path] = schema["description"].presence || compact_type(schema)
          flatten_properties(schema["properties"], path, result)
        elsif array_schema?(schema)
          flatten_array(schema, path, result)
        else
          result[path] = compact_type(schema)
        end
      end

      def flatten_array(schema, path, result)
        item_schema = effective(normalize(schema["items"]))
        if object_schema?(item_schema)
          result[path] = schema["description"].presence || nullable_suffix("array<object>", schema)
          flatten_properties(item_schema["properties"], "#{path}[0]", result)
        else
          result[path] = nullable_suffix("array<#{compact_type(item_schema)}>", schema)
        end
      end

      def property_path(parent_path, name)
        name = name.to_s
        segment =
          if name.match?(/\A[A-Za-z_$][A-Za-z0-9_$]*\z/)
            parent_path.present? ? ".#{name}" : name
          else
            "[#{JSON.generate(name)}]"
          end

        "#{parent_path}#{segment}"
      end

      def effective(schema)
        branches = schema["anyOf"]
        return schema unless branches.is_a?(Array)

        branches
          .map { |branch| effective(normalize(branch)) }
          .reduce(schema.except("anyOf")) { |combined, branch| display_union(combined, branch) }
      end

      def display_union(left, right)
        return right if left.except("$schema").empty?

        result = {}
        types = type_list(left) | type_list(right)
        result["type"] = types if types.any?

        %w[const format description].each do |key|
          result[key] = left[key] if left.key?(key) && left[key] == right[key]
        end

        if left["properties"].is_a?(Hash) || right["properties"].is_a?(Hash)
          result["properties"] = (left["properties"] || {}).merge(
            right["properties"] || {},
          ) do |_name, left_value, right_value|
            display_union(effective(normalize(left_value)), effective(normalize(right_value)))
          end
        end

        if left.key?("items") || right.key?("items")
          result["items"] = display_union(
            effective(normalize(left["items"])),
            effective(normalize(right["items"])),
          )
        end

        result
      end

      def type_list(schema)
        types = Array(schema["type"]).map(&:to_s)
        return types if types.any?
        return [json_type(schema["const"])] if schema.key?("const")
        return ["object"] if schema["properties"].is_a?(Hash)
        return ["array"] if schema.key?("items")

        []
      end

      def json_type(value)
        case value
        when Array
          "array"
        when Hash
          "object"
        when Integer
          "integer"
        when Numeric
          "number"
        when TrueClass, FalseClass
          "boolean"
        when NilClass
          "null"
        else
          "string"
        end
      end

      def compact_type(schema)
        types = type_list(schema)
        return "null" if types == ["null"]

        nullable = types.delete("null")
        types = ["unknown"] if types.empty?
        types.map! do |type|
          type == "string" && schema["format"] == "date-time" ? "datetime" : type
        end
        types << "null" if nullable
        types.join("|")
      end

      def nullable_suffix(type, schema)
        type_list(schema).include?("null") ? "#{type}|null" : type
      end

      def object_schema?(schema)
        sole_non_null_type?(schema, "object") && schema["properties"].is_a?(Hash)
      end

      def array_schema?(schema)
        sole_non_null_type?(schema, "array") && schema["items"].is_a?(Hash)
      end

      def sole_non_null_type?(schema, type)
        (type_list(schema) - ["null"]).uniq == [type]
      end

      def normalize(schema)
        return {} unless schema.respond_to?(:to_h)

        schema.to_h.deep_stringify_keys
      end
    end
  end
end
