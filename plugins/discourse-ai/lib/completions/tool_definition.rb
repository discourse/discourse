# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolDefinition
      class ParameterDefinition
        ALLOWED_TYPES = %i[string boolean integer array number].freeze
        ALLOWED_KEYS = %i[name description type required enum item_type].freeze

        attr_reader :name, :description, :type, :required, :enum, :item_type

        def self.from_hash(hash)
          extra_keys = hash.keys - ALLOWED_KEYS
          if !extra_keys.empty?
            raise ArgumentError, "Unexpected keys in parameter definition: #{extra_keys}"
          end

          new(
            name: hash[:name],
            description: hash[:description],
            type: hash[:type],
            required: hash[:required],
            enum: hash[:enum],
            item_type: hash[:item_type],
          )
        end

        def initialize(name:, description:, type:, required: false, enum: nil, item_type: nil)
          raise ArgumentError, "name must be a string" if !name.is_a?(String) || name.empty?

          if !description.is_a?(String) || description.empty?
            raise ArgumentError, "description must be a string"
          end

          type_sym = type.to_sym

          if !ALLOWED_TYPES.include?(type_sym)
            raise ArgumentError, "type must be one of: #{ALLOWED_TYPES.join(", ")}"
          end

          # Validate enum if provided
          if enum
            raise ArgumentError, "enum must be an array" if !enum.is_a?(Array)

            # Validate enum entries match the specified type
            enum.each do |value|
              case type_sym
              when :string
                if !value.is_a?(String)
                  raise ArgumentError, "enum values must be strings for type 'string'"
                end
              when :boolean
                if ![true, false].include?(value)
                  raise ArgumentError, "enum values must be booleans for type 'boolean'"
                end
              when :integer
                if !value.is_a?(Integer)
                  raise ArgumentError, "enum values must be integers for type 'integer'"
                end
              when :number
                if !value.is_a?(Numeric)
                  raise ArgumentError, "enum values must be numbers for type 'number'"
                end
              when :array
                if !value.is_a?(Array)
                  raise ArgumentError, "enum values must be arrays for type 'array'"
                end
              end
            end
          end

          if item_type && type_sym != :array
            raise ArgumentError, "item_type can only be specified for array type"
          end

          if item_type
            if !ALLOWED_TYPES.include?(item_type.to_sym)
              raise ArgumentError, "item type must be one of: #{ALLOWED_TYPES.join(", ")}"
            end
          end

          @name = name
          @description = description
          @type = type_sym
          @required = !!required
          @enum = enum
          @item_type = item_type ? item_type.to_sym : nil
        end

        def to_h
          result = { name: @name, description: @description, type: @type, required: @required }
          result[:enum] = @enum if @enum
          result[:item_type] = @item_type if @item_type
          result
        end
      end

      def parameters_json_schema
        properties = {}
        required = []

        result = { type: "object", properties: properties, required: required }

        parameters.each do |param|
          name = param.name
          required << name if param.required
          properties[name] = { type: param.type, description: param.description }
          properties[name][:items] = { type: param.item_type } if param.item_type
          properties[name][:enum] = param.enum if param.enum
        end

        result
      end

      attr_reader :name, :description, :parameters

      def self.from_hash(hash)
        allowed_keys = %i[name description parameters]
        extra_keys = hash.keys - allowed_keys
        if !extra_keys.empty?
          raise ArgumentError, "Unexpected keys in tool definition: #{extra_keys}"
        end

        params = hash[:parameters] || []
        parameter_objects =
          params.map do |param|
            if param.is_a?(Hash)
              ParameterDefinition.from_hash(param)
            else
              param
            end
          end

        new(name: hash[:name], description: hash[:description], parameters: parameter_objects)
      end

      def initialize(name:, description:, parameters: [])
        raise ArgumentError, "name must be a string" if !name.is_a?(String) || name.empty?

        if !description.is_a?(String) || description.empty?
          raise ArgumentError, "description must be a string"
        end

        raise ArgumentError, "parameters must be an array" if !parameters.is_a?(Array)

        # Check for duplicated parameter names
        param_names = parameters.map { |p| p.name }
        duplicates = param_names.select { |param_name| param_names.count(param_name) > 1 }.uniq
        if !duplicates.empty?
          raise ArgumentError, "Duplicate parameter names found: #{duplicates.join(", ")}"
        end

        @name = name
        @description = description
        @parameters = parameters
      end

      def to_h
        { name: @name, description: @description, parameters: @parameters.map(&:to_h) }
      end

      def coerce_parameters(params)
        result = {}

        return result if !params.is_a?(Hash)

        @parameters.each do |param_def|
          param_name = param_def.name.to_sym

          # Skip if parameter is not provided and not required
          next if !params.key?(param_name) && !param_def.required

          # Handle required but missing parameters
          if !params.key?(param_name) && param_def.required
            result[param_name] = nil
            next
          end

          value = params[param_name]

          # For array type, handle item coercion
          if param_def.type == :array
            result[param_name] = coerce_array_value(value, param_def.item_type)
          else
            result[param_name] = coerce_single_value(value, param_def.type)
          end
        end

        result
      end

      private

      def coerce_array_value(value, item_type)
        # Handle non-array input by attempting to parse JSON strings
        if !value.is_a?(Array)
          if value.is_a?(String)
            begin
              parsed = JSON.parse(value)
              value = parsed.is_a?(Array) ? parsed : nil
            rescue JSON::ParserError
              return nil
            end
          else
            return nil
          end
        end

        # No item type specified, return the array as is
        return value if !item_type

        # Coerce each item in the array
        value.map { |item| coerce_single_value(item, item_type) }
      end

      def coerce_single_value(value, type)
        result = nil

        case type
        when :string
          result = value.to_s
        when :integer
          if value.is_a?(Integer)
            result = value
          elsif value.is_a?(Float)
            result = value.to_i
          elsif value.is_a?(String) && value.match?(/\A-?\d+\z/)
            result = value.to_i
          end
        when :number
          if value.is_a?(Numeric)
            result = value.to_f
          elsif value.is_a?(String) && value.match?(/\A-?\d+(\.\d+)?\z/)
            result = value.to_f
          end
        when :boolean
          if value == true || value == false
            result = value
          elsif value.is_a?(String)
            if value.downcase == "true"
              result = true
            elsif value.downcase == "false"
              result = false
            end
          end
        end

        result
      end
    end
  end
end
