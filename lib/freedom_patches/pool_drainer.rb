
if Rails.version >= "4.2.0"
  class ActiveRecord::ConnectionAdapters::AbstractAdapter
    module LastUseExtension
      attr_reader :last_use

      def initialize(connection, logger = nil, pool = nil)
        super
        @last_use = false
      end

      def lease
        synchronize do
          unless in_use?
            @last_use = Time.now
            super
          end
        end
      end
    end

    prepend LastUseExtension
  end
end

class ActiveRecord::ConnectionAdapters::ConnectionPool
  # drain all idle connections
  # if idle_time is specified only connections idle for N seconds will be drained
  def drain(idle_time=nil)
    synchronize do
      @available.clear
      @connections.delete_if do |conn|
        try_drain?(conn, idle_time)
      end

      @connections.each do |conn|
        @available.add conn if !conn.in_use?
      end
    end

  end

  private

  def try_drain?(conn, idle_time)
    if !conn.in_use?
      if !idle_time || conn.last_use < idle_time.seconds.ago
        conn.disconnect!
        return true
      end
    end

    false
  end
end
