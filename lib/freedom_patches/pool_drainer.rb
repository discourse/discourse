
if Rails.version >= "4.2.0"
  class ActiveRecord::ConnectionAdapters::AbstractAdapter
    module LastUseExtension
      attr_reader :last_use, :first_use

      def initialize(connection, logger = nil, pool = nil)
        super
        @last_use = false
        @first_use = Time.now
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
  def drain(idle_time=nil, max_age=nil)
    synchronize do
      @available.clear
      @connections.delete_if do |conn|
        try_drain?(conn, idle_time, max_age)
      end

      @connections.each do |conn|
        @available.add conn if !conn.in_use?
      end
    end

  end

  private

  def try_drain?(conn, idle_time, max_age)
    if !conn.in_use?
      if !idle_time || conn.last_use < idle_time.seconds.ago || (max_age && conn.first_use < max_age.seconds.ago)
        conn.disconnect!
        return true
      end
    end

    false
  end
end
