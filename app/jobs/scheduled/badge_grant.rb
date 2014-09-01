module Jobs

  class BadgeGrant < Jobs::Scheduled
    def self.run
      self.new.execute(nil)
    end

    every 1.day

    def execute(args)
      Badge.all.each do |b|
        # Call backfill_job instead of backfill because that catches errors
        BadgeGranter.backfill_job(b)
      end
    end

  end

end
