# frozen_string_literal: true

module Jobs
  module Voice
    # Delivery backstop for call recordings: webhooks are the fast path, but
    # they are optional server configuration — this sweep resolves any
    # recording still marked live by polling the Egress service, so the
    # requester's PM and the admin log never depend on webhooks being set up.
    class ReconcileRecordings < ::Jobs::Scheduled
      every 15.minutes
      sidekiq_options retry: false
      cluster_concurrency 1

      def execute(_args)
        return unless SiteSetting.voice_enabled
        return unless SiteSetting.voice_livekit_recording_enabled
        return unless ::Voice::Livekit.configured?
        # The common case is no unresolved recordings — skip without HTTP.
        return unless ::Voice::Recording.recording.exists?

        ::Voice::RecordingManager.reconcile_pending!
      end
    end
  end
end
