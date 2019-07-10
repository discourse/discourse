# frozen_string_literal: true

module Jobs
  class RunHeartbeat < Jobs::Base
    def execute(args)
      Demon::Sidekiq.set_queue_heartbeat(args[:queue_name])
    end
  end
end
