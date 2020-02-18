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
  PG::Connection.prepend(Module.new do
    TRACE_DIR = "tmp/pgtrace"

    def initialize(*args)
      super(*args).tap do
        next if ENV["TRACE_PG_CONNECTIONS"] == "SIDEKIQ" && !Sidekiq.server?
        FileUtils.mkdir_p(TRACE_DIR)
        @trace_filename = "#{TRACE_DIR}/#{Process.pid}_#{self.object_id}.txt"
        trace File.new(@trace_filename, "w")
      end
    end

    def close
      super.tap do
        next if ENV["TRACE_PG_CONNECTIONS"] == "SIDEKIQ" && !Sidekiq.server?
        File.delete(@trace_filename)
      end
    end

  end)
end
