# frozen_string_literal: true

module DiscourseWorkflows
  class CronParser
    InvalidExpression = Class.new(StandardError)

    FieldDefinition =
      Struct.new(:name, :range, :value_extractor, :value_normalizer, keyword_init: true) do
        def value_for(time)
          normalize(value_extractor.call(time))
        end

        def normalize(value)
          return value if value_normalizer.nil?

          value_normalizer.call(value)
        end
      end

    CompiledField =
      Struct.new(:definition, :values, :unrestricted, keyword_init: true) do
        def matches?(time)
          values.include?(definition.value_for(time))
        end

        def restricted?
          !unrestricted
        end
      end

    CompiledExpression =
      Struct.new(:fields, keyword_init: true) do
        def matches?(time)
          unless fields.values_at(:minute, :hour, :month).all? { |field| field.matches?(time) }
            return false
          end

          day_of_month_match = fields[:day_of_month].matches?(time)
          day_of_week_match = fields[:day_of_week].matches?(time)

          if fields[:day_of_month].restricted? && fields[:day_of_week].restricted?
            day_of_month_match || day_of_week_match
          else
            day_of_month_match && day_of_week_match
          end
        end
      end

    FIELD_DEFINITIONS = [
      FieldDefinition.new(name: :minute, range: 0..59, value_extractor: ->(time) { time.min }),
      FieldDefinition.new(name: :hour, range: 0..23, value_extractor: ->(time) { time.hour }),
      FieldDefinition.new(
        name: :day_of_month,
        range: 1..31,
        value_extractor: ->(time) { time.mday },
      ),
      FieldDefinition.new(name: :month, range: 1..12, value_extractor: ->(time) { time.month }),
      FieldDefinition.new(
        name: :day_of_week,
        range: 0..7,
        value_extractor: ->(time) { time.wday },
        value_normalizer: ->(value) { value == 7 ? 0 : value },
      ),
    ].freeze

    def self.matches?(expression, time)
      compiled = compile(expression)
      compiled.present? && compiled.matches?(time)
    end

    def self.valid?(expression)
      compile(expression).present?
    end

    def self.compile(expression)
      fields = tokenize(expression)

      compiled_fields =
        FIELD_DEFINITIONS.each_with_index.to_h do |definition, index|
          [definition.name, compile_field(fields[index], definition)]
        end

      CompiledExpression.new(fields: compiled_fields.freeze)
    rescue InvalidExpression
      nil
    end

    def self.tokenize(expression)
      raise InvalidExpression if expression.blank?

      fields = expression.strip.split(/\s+/)
      raise InvalidExpression unless fields.size == FIELD_DEFINITIONS.size

      fields
    end

    def self.compile_field(field, definition)
      values = Set.new

      field
        .split(",")
        .each do |part|
          raise InvalidExpression if part.blank?

          expand_part(part, definition).each { |value| values << value }
        end

      raise InvalidExpression if values.empty?

      CompiledField.new(definition: definition, values: values.freeze, unrestricted: field == "*")
    end

    def self.expand_part(part, definition)
      case part
      when "*"
        normalize_values(definition.range, definition)
      when %r{\A\*/(\d+)\z}
        expand_range(definition.range.begin, definition.range.end, $1, definition)
      when %r{\A(\d+)-(\d+)(?:/(\d+))?\z}
        expand_range($1.to_i, $2.to_i, $3 || 1, definition)
      when /\A(\d+)\z/
        [normalize_value($1.to_i, definition)]
      else
        raise InvalidExpression
      end
    end

    def self.expand_range(start_value, end_value, step, definition)
      step = Integer(step)

      raise InvalidExpression if step <= 0
      raise InvalidExpression if start_value > end_value
      raise InvalidExpression unless definition.range.cover?(start_value)
      raise InvalidExpression unless definition.range.cover?(end_value)

      normalize_values((start_value..end_value).step(step), definition)
    end

    def self.normalize_value(value, definition)
      raise InvalidExpression unless definition.range.cover?(value)

      definition.normalize(value)
    end

    def self.normalize_values(values, definition)
      values.map { |value| definition.normalize(value) }
    end

    private_class_method :tokenize, :compile_field, :expand_part, :expand_range
    private_class_method :normalize_value, :normalize_values
  end
end
