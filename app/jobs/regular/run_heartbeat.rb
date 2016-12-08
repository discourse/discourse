module Jobs
  class RunHeartbeat < Jobs::Base

    sidekiq_options queue: 'critical'

    def self.heartbeat_key
      'heartbeat_last_run'
    end

    def execute(args)
      $redis.set(self.class.heartbeat_key, Time.new.to_i.to_s)
    end

    def self.last_heartbeat
      $redis.get(heartbeat_key).to_i
    end
  end
end
