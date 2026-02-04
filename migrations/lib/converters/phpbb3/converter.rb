# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class Converter < ::Migrations::Converters::Base::Converter
    def initialize(settings)
      super
      @source_db = create_source_db_adapter
    end

    def step_args(step_class)
      { source_db: @source_db }
    end

    private

    def create_source_db_adapter
      db_settings = settings[:source_db]
      db_type = (db_settings[:type] || "mysql").to_sym

      case db_type
      when :mysql
        ::Migrations::Database::Adapter::Mysql.new(db_settings)
      when :postgres
        ::Migrations::Database::Adapter::Postgres.new(db_settings)
      else
        raise ArgumentError, "Unsupported database type: #{db_type}"
      end
    end
  end
end
