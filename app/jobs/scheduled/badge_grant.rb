module Jobs

  class BadgeGrant < Jobs::Scheduled
    def self.run
      self.new.execute(nil)
    end

    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges

      Badge.all.each do |b|
        BadgeGranter.backfill(b)
      end

      BadgeGranter.revoke_ungranted_titles!
    end

  end

end
