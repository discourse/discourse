# frozen_string_literal: true

# This patch has been added to address the problems identified in https://github.com/rails/rails/issues/35311. For every,
# new connection created using the PostgreSQL adapter, 3 queries are executed to fetch the type map adding about 1ms overhead
# to every connection creation. In multisite clusters where connections are reaped more aggressively, the 3 queries executed
# accounts for a significant portion of CPU usage on the PostgreSQL cluster. This patch works around the problem by
# caching the type map in a class level attribute to reuse across connections.
#
# The latest attempt to fix the problem in Rails is in https://github.com/rails/rails/pull/46409 but it has gone stale.
module FreedomPatches
  module PostgreSQLAdapter
    # Definition as of writing: https://github.com/rails/rails/blob/5bf5344521a6f305ca17e0004273322a0a26f50a/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L316
    def reload_type_map
      self.class.type_map = nil
      super
    end

    # Definition as of writing: https://github.com/rails/rails/blob/5bf5344521a6f305ca17e0004273322a0a26f50a/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L614
    def initialize_type_map(m = type_map)
      if !self.class.type_map.nil?
        @type_map = self.class.type_map
      else
        super.tap { self.class.type_map = @type_map }
      end
    end
  end

  module PostgreSQLAdapterClassMethods
    extend ActiveSupport::Concern

    included do
      @type_map_mutex = Mutex.new
      @type_map = nil

      def self.type_map
        @type_map_mutex.synchronize { @type_map }
      end

      def self.type_map=(type_map)
        @type_map_mutex.synchronize { @type_map = type_map }
      end
    end
  end

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(FreedomPatches::PostgreSQLAdapter)

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(
    FreedomPatches::PostgreSQLAdapterClassMethods,
  )
end
