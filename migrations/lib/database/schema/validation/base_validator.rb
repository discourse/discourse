# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class BaseValidator
    def initialize(config, errors, db)
      @config = config
      @schema_config ||= @config[:schema]
      @errors = errors
      @db = db
    end

    private

    def sort_and_join(values)
      values.sort.join(", ")
    end
  end
end
