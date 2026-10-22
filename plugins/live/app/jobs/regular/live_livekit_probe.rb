# frozen_string_literal: true

module Jobs
  # One-shot connectivity probe enqueued whenever a LiveKit setting changes,
  # so a bad URL or key pair surfaces on the admin status panel (and in the
  # logs) within seconds of saving — not at the first user's failed join.
  class LiveLivekitProbe < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      unless ::Live::Livekit.configured?
        # Deconfiguring is also a settings change: drop the stale result
        # instead of reporting the health of a server we no longer use.
        ::Live::Livekit::HealthCheck.clear_probe!
        return
      end

      result = ::Live::Livekit::HealthCheck.connectivity_check
      ::Live::Livekit::HealthCheck.store_probe!(result)

      ::Live.warn("[live-livekit] connectivity probe failed") if !result[:ok]
    end
  end
end
