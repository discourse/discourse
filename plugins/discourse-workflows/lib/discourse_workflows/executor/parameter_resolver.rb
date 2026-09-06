# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ParameterResolver
      MISSING = Object.new.freeze
      BOOLEAN_TYPE = ActiveModel::Type::Boolean.new

      def initialize(parameters:, property_schema:, resolver:, input_items:, runtime_state:)
        @parameters = parameters
        @property_schema = property_schema
        @resolver = resolver
        @input_items = input_items
        @runtime_state = runtime_state
      end

      def resolve(path, item_index = 0, default: nil, options: {})
        path_str = path.to_s
        if raw_expressions?(options)
          raw_value = raw_parameter_path(path_str)
          return raw_value.equal?(MISSING) ? default : raw_value
        end

        with_item_index(item_index) do
          resolved = resolve_parameter_path(path_str)
          resolved.equal?(MISSING) ? default : resolved
        end
      end

      private

      def with_item_index(item_index = 0)
        normalized_item_index = normalize_item_index(item_index)
        item = @input_items.fetch(normalized_item_index) { { "json" => {} } }

        @resolver.with_item(item, item_index: normalized_item_index) { yield item }
      end

      def normalize_item_index(item_index)
        return 0 if item_index.nil?
        return item_index if item_index.is_a?(Integer)

        raise ArgumentError, "item_index must be an Integer"
      end

      def raw_expressions?(options)
        options&.fetch(:raw_expressions, false)
      end

      def raw_parameter_path(path)
        segments = path.split(".").reject(&:blank?)
        return MISSING if segments.empty?
        return MISSING unless @parameters.key?(segments.first)

        if segments.one?
          @parameters[segments.first]
        else
          dig_parameter_path(@parameters[segments.first], segments.drop(1))
        end
      end

      def resolve_parameter(name, schema)
        return @parameters[name] if no_data_expression?(schema)

        if condition_builder_schema?(schema)
          conditions = @parameters.fetch("conditions") { [] }
          combinator = @parameters.fetch("combinator") { "and" }
          options = @parameters.fetch("options") { {} }
          result =
            Executor::FilterParameter.execute_filter(conditions, combinator, options, @resolver)
          @runtime_state.add_condition_details(result["details"])
          result["passed"]
        else
          resolve_parameter_value(@parameters[name], schema)
        end
      end

      def resolve_parameter_value(value, schema = nil)
        return value if no_data_expression?(schema)
        return resolve_fixed_collection_value(value, schema) if fixed_collection_schema?(schema)
        return resolve_collection_value(value, schema) if collection_schema?(schema)

        resolved_value =
          case value
          when Hash
            resolve_hash_parameter_value(value, schema)
          when Array
            item_schema = schema_value(schema, :item_schema)
            value.map { |entry| resolve_parameter_value(entry, item_schema) }
          else
            @resolver.resolve(value)
          end

        coerce_parameter_value(resolved_value, schema)
      end

      def resolve_hash_parameter_value(value, schema)
        fields = schema_value(schema, :fields) || {}

        value.transform_values.with_index do |nested_value, index|
          key = value.keys[index]
          nested_schema = fields[key.to_sym] || fields[key.to_s]
          resolve_parameter_value(nested_value, nested_schema)
        end
      end

      def resolve_fixed_collection_value(value, schema)
        unless value.is_a?(Hash)
          return(
            resolve_fixed_collection_group_value(value, first_fixed_collection_row_schema(schema))
          )
        end

        value.transform_values.with_index do |group_value, index|
          group_name = value.keys[index]
          row_schema = fixed_collection_row_schema(schema, group_name)
          resolve_fixed_collection_group_value(group_value, row_schema)
        end
      end

      def resolve_collection_value(value, schema)
        if value.is_a?(Hash)
          return(
            value.transform_values.with_index do |option_value, index|
              option_name = value.keys[index]
              option_schema = collection_option_schema(schema, option_name)
              resolve_parameter_value(option_value, option_schema)
            end
          )
        end

        resolve_parameter_value(value, schema_value(schema, :item_schema))
      end

      def collection_option_schema(schema, option_name)
        option =
          Array(schema_value(schema, :options)).find do |entry|
            (schema_value(entry, :name) || "").to_s == option_name.to_s
          end

        option&.except(:name, "name", :display_name, "display_name")
      end

      def resolve_fixed_collection_group_value(value, row_schema)
        case value
        when Array
          value.map { |row| resolve_parameter_value(row, { type: :object, fields: row_schema }) }
        when Hash
          resolve_parameter_value(value, { type: :object, fields: row_schema })
        else
          resolve_parameter_value(value)
        end
      end

      def fixed_collection_row_schema(schema, group_name)
        group =
          Array(schema_value(schema, :options)).find do |option|
            (schema_value(option, :name) || "").to_s == group_name.to_s
          end

        schema_value(group, :values) || {}
      end

      def first_fixed_collection_row_schema(schema)
        schema_value(Array(schema_value(schema, :options)).first, :values) || {}
      end

      def resolve_parameter_path(path)
        segments = path.split(".").reject(&:blank?)
        return MISSING if segments.empty?

        name = segments.first
        schema = @property_schema[name.to_sym] || @property_schema[name]
        if !@parameters.key?(name)
          return resolve_parameter(name, schema) if condition_builder_schema?(schema)

          return MISSING
        end

        resolved = resolve_parameter(name, schema)
        return resolved if segments.one?

        dig_parameter_path(resolved, segments.drop(1))
      end

      def dig_parameter_path(value, segments)
        segments.reduce(value) do |current, segment|
          case current
          when Hash
            return MISSING unless current.key?(segment)

            current[segment]
          when Array
            return MISSING unless segment.match?(/\A\d+\z/)

            current.fetch(segment.to_i) { return MISSING }
          else
            return MISSING
          end
        end
      end

      def condition_builder_schema?(schema)
        schema.is_a?(Hash) && schema.dig(:ui, :control) == :condition_builder
      end

      def fixed_collection_schema?(schema)
        schema_value(schema, :type).to_s == "fixed_collection"
      end

      def collection_schema?(schema)
        schema_value(schema, :type).to_s == "collection"
      end

      def no_data_expression?(schema)
        schema_value(schema, :no_data_expression) == true
      end

      def coerce_parameter_value(value, schema)
        return value if schema_value(schema, :type).to_s != "boolean"

        BOOLEAN_TYPE.cast(value) == true
      end

      def schema_value(schema, key)
        return nil unless schema.respond_to?(:[])

        schema[key] || schema[key.to_s]
      end
    end
  end
end
