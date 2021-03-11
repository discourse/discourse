# frozen_string_literal: true
#
# Rails has a circular dependency in SchemaCache.
# In certain situation SchemaCache can carry a @connection
# from a different thread. This causes potential concurrency bugs
# in Sidekiq.
#
# This patches it so it is less flexible (theoretically) but always bound to the current connection

# This patch needs to be reviewed in future versions of Rails.
# We should consider upstreaming this optionally.

module ActiveRecord
  module ConnectionAdapters
    class SchemaCache

      def connection=(connection)
        # AbstractPool get_schema_cache does schema_cache.connection = connection
        Thread.current["schema_cached_connection"] = connection
      end

      def connection
        Thread.current["schema_cached_connection"]
      end
    end
  end
end
