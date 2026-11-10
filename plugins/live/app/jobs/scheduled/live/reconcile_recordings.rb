# frozen_string_literal: true

module Jobs
  module Live
    # Delivery backstop for call recordings: webhooks are the fast path, but
    # they are optional server configuration — this sweep resolves any
    # recording still marked live by polling the Egress service, so the
    # requester's PM and the admin log never depend on webhooks being set up.
    class ReconcileRecordings < ::Jobs::Scheduled
      every 15.minutes
      sidekiq_options retry: false
      cluster_concurrency 1

      def execute(_args)
        return unless SiteSetting.live_enabled
        return unless SiteSetting.live_livekit_recording_enabled
        return unless ::Live::Livekit.configured?
        # The common case is no unresolved recordings — skip without HTTP.
        return unless ::Live::Recording.recording.exists?

        ::Live::RecordingManager.reconcile_pending!
      end
    end
  end
end
