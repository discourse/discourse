# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  Convention = Data.define(:name, :pattern, :rename_to, :type_override, :required)

  ConventionsConfig =
    Data.define(:conventions, :ignored_columns) do
      def effective_name(column_name)
        convention = convention_for(column_name)
        return convention.rename_to if convention&.rename_to
        column_name.to_s
      end

      def convention_for(column_name)
        column_name = column_name.to_s
        # Exact name match first, then regex pattern match
        conventions.find { |c| c.name == column_name } ||
          conventions.find { |c| c.pattern&.match?(column_name) }
      end

      def required?(column_name)
        convention_for(column_name)&.required == true
      end

      def ignored_column?(column_name)
        ignored_columns.include?(column_name.to_s)
      end
    end

  class ConventionsBuilder
    def initialize
      @conventions = []
      @ignored_columns = []
    end

    def column(name, &block)
      builder = ConventionEntryBuilder.new(name: name.to_s)
      builder.instance_eval(&block)
      @conventions << builder.build
    end

    def columns_matching(pattern, &block)
      pattern = Regexp.new(pattern) unless pattern.is_a?(Regexp)
      builder = ConventionEntryBuilder.new(pattern:)
      builder.instance_eval(&block)
      @conventions << builder.build
    end

    def ignore_columns(*names)
      @ignored_columns.concat(names.flatten.map(&:to_s))
    end

    def build
      ConventionsConfig.new(
        conventions: @conventions.freeze,
        ignored_columns: @ignored_columns.freeze,
      )
    end
  end

  class ConventionEntryBuilder
    def initialize(name: nil, pattern: nil)
      @name = name
      @pattern = pattern
      @rename_to = nil
      @type_override = nil
      @required = nil
    end

    def rename_to(value)
      @rename_to = value.to_s
    end

    def type(value)
      @type_override = value.to_s
    end

    def required(value = true)
      @required = value
    end

    def build
      Convention.new(
        name: @name,
        pattern: @pattern,
        rename_to: @rename_to,
        type_override: @type_override,
        required: @required,
      )
    end
  end
end
