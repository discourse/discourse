# frozen_string_literal: true

module Jobs

  # used to ensure at least 1 sidekiq is running correctly
  class Heartbeat < Jobs::Scheduled
    every 3.minute

    def execute(args)
      Demon::Sidekiq::QUEUE_IDS.each do |identifier|
        Jobs.enqueue(:run_heartbeat, queue_name: identifier, queue: identifier)
      end
    end
  end
end
