# frozen_string_literal: true

module DiscourseWorkflows
  class CronParser
    InvalidExpression = Class.new(StandardError)

    FieldDefinition =
      Struct.new(
        :name,
        :range,
        :value_extractor,
        :value_normalizer,
        :aliases,
        keyword_init: true,
      ) do
        def value_for(time)
          normalize(value_extractor.call(time))
        end

        def normalize(value)
          return value if value_normalizer.nil?

          value_normalizer.call(value)
        end

        def value_from_token(token)
          aliases&.fetch(token.to_s.upcase, nil) || Integer(token)
        rescue ArgumentError, TypeError
          raise InvalidExpression
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
          unless fields
                   .values_at(:second, :minute, :hour, :month)
                   .all? { |field| field.matches?(time) }
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

    MONTH_ALIASES =
      %w[JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC]
        .each_with_index
        .to_h { |name, index| [name, index + 1] }
        .freeze

    WEEKDAY_ALIASES = %w[SUN MON TUE WED THU FRI SAT].each_with_index.to_h.freeze

    FIELD_DEFINITIONS = [
      FieldDefinition.new(name: :second, range: 0..59, value_extractor: ->(time) { time.sec }),
      FieldDefinition.new(name: :minute, range: 0..59, value_extractor: ->(time) { time.min }),
      FieldDefinition.new(name: :hour, range: 0..23, value_extractor: ->(time) { time.hour }),
      FieldDefinition.new(
        name: :day_of_month,
        range: 1..31,
        value_extractor: ->(time) { time.mday },
      ),
      FieldDefinition.new(
        name: :month,
        range: 1..12,
        value_extractor: ->(time) { time.month },
        aliases: MONTH_ALIASES,
      ),
      FieldDefinition.new(
        name: :day_of_week,
        range: 0..7,
        value_extractor: ->(time) { time.wday },
        value_normalizer: ->(value) { value == 7 ? 0 : value },
        aliases: WEEKDAY_ALIASES,
      ),
    ].freeze

    def self.matches?(expression, time)
      compiled = compile(expression)
      compiled.present? && compiled.matches?(time)
    end

    def self.valid?(expression)
      compile(expression).present?
    end

    def self.minute_granularity?(expression)
      fields = tokenize(expression)
      second_field = compile_field(fields.first, FIELD_DEFINITIONS.first)
      second_field.values == Set[0]
    rescue InvalidExpression
      false
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
      fields.unshift("0") if fields.size == FIELD_DEFINITIONS.size - 1
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
      when %r{\A([[:alnum:]]+)-([[:alnum:]]+)(?:/(\d+))?\z}
        expand_range(
          definition.value_from_token($1),
          definition.value_from_token($2),
          $3 || 1,
          definition,
        )
      when /\A[[:alnum:]]+\z/
        [normalize_value(definition.value_from_token(part), definition)]
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
