# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Converter < ::Migrations::Converters::Base::Converter
    def initialize(settings)
      super
      @source_db = ::Migrations::Database::Adapter::Postgres.new(settings[:source_db])
    end

    def step_args(step_class)
      { source_db: @source_db }
    end
  end
end
