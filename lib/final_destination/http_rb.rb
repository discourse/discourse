# frozen_string_literal: true

require "http"

class FinalDestination
  # http.rb's chainable DSL (HTTPRb.get(url), HTTPRb.timeout(5).post(url, ...)) connecting
  # through FinalDestination::SSRFSafeSocket. HTTP builds each request's client from
  # #default_options, so the socket class applies to plain verbs and chained calls alike.
  module HTTPRb
    # ::HTTP is the gem; bare HTTP would resolve to FinalDestination::HTTP.
    extend ::HTTP::Chainable

    def self.default_options
      @default_options ||= ::HTTP::Options.new(socket_class: FinalDestination::SSRFSafeSocket)
    end
  end
end
