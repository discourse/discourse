module Jobs
  class ClockworkHeartbeat < Jobs::Base

    def execute(args)
      $redis.set last_heartbeat_at_key, Time.now.to_i
    end

    def self.is_clockwork_running?
      if time = ClockworkHeartbeat.new.last_heartbeat_at
        time > 2.minutes.ago
      else
        false
      end
    end

    def last_heartbeat_at
      if time_int = $redis.get(last_heartbeat_at_key)
        Time.at(time_int.to_i)
      else
        nil
      end
    end

    private

      def last_heartbeat_at_key
        'clockwork:last_heartbeat_at'
      end

  end
end