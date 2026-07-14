# frozen_string_literal: true

module Middleware
  class TrackViewSessionIdInjector
    PLACEHOLDER_HEADER = "Discourse-Track-View-Session-Id-Placeholder"

    def initialize(app, settings = {})
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      if placeholder = headers.delete(PLACEHOLDER_HEADER)
        session_id = SecureRandom.alphanumeric(Middleware::RequestTracker::MAX_SESSION_ID_LENGTH)
        parts = []
        response.each { |part| parts << part.to_s.sub(placeholder, session_id) }
        [status, headers, parts]
      else
        [status, headers, response]
      end
    end
  end
end
