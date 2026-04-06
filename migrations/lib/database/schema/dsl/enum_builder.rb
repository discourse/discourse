# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      module DSL
        EnumDef = Data.define(:name, :values, :datatype)

        class EnumBuilder
          def initialize(name)
            @name = name.to_s
            @values = {}
            @source_block = nil
          end

          def value(name, val)
            @values[name.to_s] = val
          end

          def source(&block)
            @source_block = block
          end

          def build
            values = resolve_values
            if values.empty?
              raise ConfigError, "Enum :#{@name} must define at least one value or a source."
            end
            datatype = validate_and_infer_datatype(values)
            EnumDef.new(name: @name, values: values.freeze, datatype:)
          end

          private

          def resolve_values
            if @source_block
              evaluate_source
            else
              @values
            end
          end

          def evaluate_source
            result = @source_block.call
            case result
            when Hash
              result.transform_keys(&:to_s)
            when Array
              result.each_with_index.to_h { |k, i| [k.to_s, i] }
            else
              raise ConfigError,
                    "Enum :#{@name} source must return a Hash or Array, got #{result.class}."
            end
          rescue ConfigError
            raise
          rescue StandardError => e
            raise ConfigError, "Enum :#{@name} failed to evaluate source: #{e.message}"
          end

          def validate_and_infer_datatype(values)
            types = values.values.map(&:class).uniq

            if types.size > 1
              raise ConfigError, "Enum :#{@name} values must all be Strings or all Integers"
            end

            type = types.first
            if type == String
              :text
            elsif type == Integer
              :integer
            else
              raise ConfigError,
                    "Enum :#{@name} values must be Strings or Integers, got #{types.first}"
            end
          end
        end
      end
    end
  end
end
