# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      module DatabasePool
        # Sets up the AR connection for the upload workers, with a single
        # `establish_connection`:
        #
        # * The pool grows up to the server's `max_connections`. Each worker
        #   thread uses its own connection, and the worker limit depends on the
        #   pool size.
        # * With `synchronous_commit: false`, a COMMIT does not wait for the WAL
        #   to be flushed to disk. Creating an upload commits several times, and
        #   that wait is a large part of its time. A crash can lose only the last
        #   commits, and the next run creates those uploads again, because the
        #   tasks only skip ids that are already recorded.
        #
        # Session variables in the connection config are set on every connection
        # the pool opens, including reconnects, and on no other session.
        def self.configure!(synchronous_commit: true)
          max_connections = ::DB.query_single("SHOW max_connections").first.to_i
          widen = ActiveRecord::Base.connection_pool.size < max_connections
          return if !widen && synchronous_commit

          config = ActiveRecord::Base.connection_db_config.configuration_hash.deep_dup
          config[:pool] = max_connections if widen
          (config[:variables] ||= {})[:synchronous_commit] = "off" if !synchronous_commit
          ActiveRecord::Base.establish_connection(config)
        end
      end
    end
  end
end
