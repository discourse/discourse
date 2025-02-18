# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class BaseValidator
    def initialize(schema_config, db, errors)
      @schema_config = schema_config
      @db = db
      @errors = errors
    end

    private

    def sort_and_join(values)
      values.sort.join(", ")
    end
  end
end
