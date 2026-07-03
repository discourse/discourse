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

      # The conflict strategy a table's model declares for its inserts, so the
      # shard merge can mirror it (see `Conversion::Consolidator`). A model that
      # inserts with `INSERT OR IGNORE` declares `:ignore`; everything else falls
      # back to `:raise`, keeping the single-writer contract where a genuine
      # duplicate row is an error rather than a silently dropped row. Derived from
      # the model itself, so a new `OR IGNORE` table needs no change here.
      def self.conflict_strategy_for(table)
        module_name = table.to_s.singularize.camelize
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
