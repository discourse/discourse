# frozen_string_literal: true

module Migrations::Importer
  class Step
    NOW = "NOW()"

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
      @last_id = 0
    end

    private

    def query(sql, *parameters)
      Enumerator.new do |y|
        @intermediate_db.query(sql, *parameters) { |row| y << process_row(row) }
      end
    end

    def process_row(row)
      row
    end

    def set_id(row)
      row[:original_id] = row[:id]
      row[:id] = @last_id += 1
    end

    def set_dates(row)
      row[:created_at] ||= NOW
      row[:updated_at] ||= row[:created_at]
    end
  end
end
