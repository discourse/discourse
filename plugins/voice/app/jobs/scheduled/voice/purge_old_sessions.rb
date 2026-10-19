# frozen_string_literal: true

module Jobs
  module Voice
    class PurgeOldSessions < ::Jobs::Scheduled
      every 1.day

      def execute(_args)
        return unless SiteSetting.voice_enabled

        days = SiteSetting.voice_session_retention_days
        return if days <= 0

        cutoff = days.days.ago
        ::Voice::Session.where("created_at < ?", cutoff).in_batches(of: 1000).delete_all
        ::Voice::CoPresence.where("date < ?", cutoff.to_date).in_batches(of: 1000).delete_all
      end
    end
  end
end
