module Jobs

  # used to ensure at least 1 sidekiq is running correctly
  class Heartbeat < Jobs::Scheduled
    every 3.minute

    def execute(args)
      Jobs.enqueue(:run_heartbeat, {})
    end
  end
end
