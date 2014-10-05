module Jobs
  class ProcessBadgeBacklog < Jobs::Scheduled
    every 1.minute
    def execute(args)
      BadgeGranter.process_queue!
    end
  end
end
