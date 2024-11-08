# frozen_string_literal: true

# Setting TRACE_PG_CONNECTIONS=1 will cause all pg connections
# to be streamed to files for debugging. The filenames are formatted
# like tmp/pgtrace/{{PID}}_{{CONNECTION_OBJECT_ID}}.txt
#
# Setting TRACE_PG_CONNECTIONS=SIDEKIQ will only trace connections
# on in sidekiq (safer, because there will be minimal user-facing perf impact)
#
# Files will be automatically deleted when the connection is closed gracefully
# (e.g. when activerecord closes it after a period of inactivity)
# Files will not be automatically deleted when closed abruptly
# (e.g. terminating/restarting the app process)
#
# Warning: this could create some very large files!

if ENV["TRACE_PG_CONNECTIONS"]
  PG::Connection.prepend(
    Module.new do
      TRACE_DIR = "tmp/pgtrace"

      def initialize(*args)
        super(*args).tap do
          next if ENV["TRACE_PG_CONNECTIONS"] == "SIDEKIQ" && !Sidekiq.server?
          FileUtils.mkdir_p(TRACE_DIR)
          @trace_filename = "#{TRACE_DIR}/#{Process.pid}_#{self.object_id}.txt"
          trace File.new(@trace_filename, "w")
        end
        @access_log_mutex = Mutex.new
        @accessor_thread = nil
      end

      def close
        super.tap do
          next if ENV["TRACE_PG_CONNECTIONS"] == "SIDEKIQ" && !Sidekiq.server?
          File.delete(@trace_filename)
        end
      end

      def log_access(&blk)
        @access_log_mutex.synchronize do
          if !@accessor_thread.nil?
            Rails.logger.error <<~TEXT
            PG Clash: A connection is being accessed from two locations

            #{@accessor_thread} was using the connection. Backtrace:

            #{@accessor_thread&.backtrace&.join("\n")}

            #{Thread.current} is now attempting to use the connection. Backtrace:

            #{Thread.current&.backtrace&.join("\n")}
          TEXT

            if ENV["ON_PG_CLASH"] == "byebug"
              require "byebug"
              byebug # rubocop:disable Lint/Debugger
            end
          end
          @accessor_thread = Thread.current
        end
        yield
      ensure
        @access_log_mutex.synchronize { @accessor_thread = nil }
      end
    end,
  )

  class PG::Connection
    LOG_ACCESS_METHODS = %i[
      exec
      sync_exec
      async_exec
      sync_exec_params
      async_exec_params
      sync_prepare
      async_prepare
      sync_exec_prepared
      async_exec_prepared
    ].freeze

    LOG_ACCESS_METHODS.each do |method|
      new_method = "#{method}_without_logging".to_sym
      alias_method new_method, method

      define_method(method) { |*args, &blk| log_access { send(new_method, *args, &blk) } }
    end
  end
end
