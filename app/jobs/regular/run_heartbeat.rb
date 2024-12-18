# frozen_string_literal: true

# This job is deprecated and will be removed in the future. The only reason it exists is for clean up purposes.
module Jobs
  class RunHeartbeat < ::Jobs::Base
    def self.heartbeat_key
      "heartbeat_last_run"
    end

    def execute(args)
      Discourse.redis.del(self.class.heartbeat_key)
    end
  end
end
