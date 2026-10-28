# frozen_string_literal: true

module Jobs
  module Live
    class PurgeOldSessions < ::Jobs::Scheduled
      every 1.day

      def execute(_args)
        return unless SiteSetting.live_enabled

        days = SiteSetting.live_session_retention_days
        return if days <= 0

        cutoff = days.days.ago
        ::Live::Session.where("created_at < ?", cutoff).in_batches(of: 1000).delete_all
        ::Live::CoPresence.where("date < ?", cutoff.to_date).in_batches(of: 1000).delete_all
      end
    end
  end
end
