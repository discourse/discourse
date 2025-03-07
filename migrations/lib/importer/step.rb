# frozen_string_literal: true

module Migrations::Importer
  class Step
    def self.depends_on(*step_names)
      steps_module = ::Migrations::Importer::Steps
      classes =
        step_names.map do |name|
          name = name.to_s.capitalize
          klass = steps_module.const_get(name) if steps_module.const_defined?(name)

          unless klass.is_a?(Class) && klass < ::Migrations::Importer::Step
            raise NameError, "Class #{class_name} not found"
          end

          klass
        end

      @dependencies ||= []
      @dependencies.concat(classes)
    end

    def self.dependencies
      @dependencies || []
    end

    def initialize(intermediate_db, discourse_db)
      @intermediate_db = intermediate_db
      @discourse_db = discourse_db
    end
  end
end
