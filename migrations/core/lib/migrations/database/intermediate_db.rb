# frozen_string_literal: true

module Migrations
  module Database
    module IntermediateDB
      def self.setup(db_connection)
        close
        @db = db_connection
      end

      # Swaps the connection for the duration of the block. Unlike `setup`,
      # neither connection is closed, and the previous one is restored even
      # when the block raises.
      def self.with_connection(db_connection)
        previous_connection = @db
        @db = db_connection
        yield
      ensure
        @db = previous_connection
      end

      def self.insert(sql, *parameters)
        @db.insert(sql, parameters)
      end

      # Returns `:ignore` for models using `INSERT OR IGNORE`, otherwise `:raise`.
      def self.conflict_strategy_for(table)
        module_name = table.singularize.camelize
        return :raise unless const_defined?(module_name, false)

        model = const_get(module_name, false)
        model.respond_to?(:conflict_strategy) ? model.conflict_strategy : :raise
      end

      def self.close
        @db.close if @db
      end
    end
  end
end
