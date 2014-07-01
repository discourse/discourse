module Jobs

  class BadgeGrant < Jobs::Scheduled
    every 1.day

    def execute(args)
      BadgeGranter.backfill_like_badges
    end

  end

end
