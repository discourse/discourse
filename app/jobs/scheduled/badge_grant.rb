module Jobs

  class BadgeGrant < Jobs::Scheduled
    def self.run
      self.new.execute(nil)
    end

    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges

      Badge.enabled.find_each do |b|
        begin
          BadgeGranter.backfill(b)
        rescue => ex
          # TODO - expose errors in UI
          Discourse.handle_job_exception(ex, error_context({}, code_desc: 'Exception granting badges', extra: { badge_id: b.id }))
        end
      end

      BadgeGranter.revoke_ungranted_titles!
    end

  end

end
