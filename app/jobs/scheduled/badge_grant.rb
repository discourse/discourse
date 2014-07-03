module Jobs

  class BadgeGrant < Jobs::Scheduled
    every 1.day

    def execute(args)
      Badge.all.each do |b|
        BadgeGranter.backfill(b)
      end
    end

  end

end
