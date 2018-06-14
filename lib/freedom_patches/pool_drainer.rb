class ActiveRecord::ConnectionAdapters::AbstractAdapter
  module LastUseExtension
    attr_reader :last_use, :first_use

    def initialize(connection, logger = nil, pool = nil)
      super
      @last_use = false
      @first_use = Time.now
    end

    def lease
      @lock.synchronize do
        unless in_use?
          @last_use = Time.now
          super
        end
      end
    end
  end

  prepend LastUseExtension
end

class ActiveRecord::ConnectionAdapters::ConnectionPool
  # drain all idle connections
  # if idle_time is specified only connections idle for N seconds will be drained
  def drain(idle_time = nil, max_age = nil)
    return if !(@connections && @available)

    idle_connections = synchronize do
      @connections.select do |conn|
        !conn.in_use? && ((idle_time && conn.last_use <= idle_time.seconds.ago) || (max_age && conn.first_use < max_age.seconds.ago))
      end.each do |conn|
        conn.lease

        @available.delete conn
        @connections.delete conn
      end
    end

    idle_connections.each do |conn|
      conn.disconnect!
    end

  end

end
