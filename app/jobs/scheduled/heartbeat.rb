# frozen_string_literal: true

module Jobs

  # used to ensure at least 1 sidekiq is running correctly
  class Heartbeat < Jobs::Scheduled
    every 3.minute

    def execute(args)
      Demon::Sidekiq.heartbeat_queues.each do |queue|
        Jobs.enqueue(:run_heartbeat, queue_name: queue, queue: queue)
      end
    end
  end
end
