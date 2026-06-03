# frozen_string_literal: true

module Migrations
  class ClassFilter
    class UnknownClassNamesError < StandardError
      attr_reader :missing_names, :available_names

      def initialize(missing_names, available_names)
        @missing_names = missing_names.sort
        @available_names = available_names.sort
        super("Unknown class names: #{missing_names.join(", ")}")
      end
    end

    def self.filter(classes, skip: [], only: [])
      new(classes, skip:, only:).filter
    end

    def initialize(classes, skip: [], only: [])
      @classes = classes
      @skip = skip
      @only = only
      @normalized_class_names = build_normalized_names
    end

    def filter
      validate_class_names!

      classes_to_include = @classes.dup
      classes_to_include.select! { |klass| class_included?(@only, klass) } if @only.any?
      classes_to_include.reject! { |klass| class_included?(@skip, klass) } if @skip.any?

      classes_with_dependencies = Set.new(classes_to_include)
      classes_to_include.each { |klass| add_dependencies(klass, classes_with_dependencies) }

      classes_with_dependencies.to_a
    end

    private

    def build_normalized_names
      Hash[@classes.map { |klass| [klass, klass.name.demodulize.underscore] }]
    end

    def validate_class_names!
      available_names = @normalized_class_names.values
      all_specified_names = (@skip + @only).uniq
      missing_names = all_specified_names - available_names

      raise UnknownClassNamesError.new(missing_names, available_names) if missing_names.any?
    end

    def add_dependencies(klass, included_set)
      return unless klass.respond_to?(:dependencies) && klass.dependencies.present?

      klass.dependencies.each do |dependency|
        next if class_included?(@skip, dependency)
        next if included_set.include?(dependency)

        included_set << dependency
        add_dependencies(dependency, included_set)
      end
    end

    def class_included?(class_names, klass)
      class_names.include?(@normalized_class_names[klass])
    end
  end
end
