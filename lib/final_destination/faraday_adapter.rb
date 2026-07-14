# frozen_string_literal: true

require "faraday/adapter/http"

class FinalDestination
  # Faraday adapter driving http.rb through FinalDestination::HTTPRb for SSRF-filtered,
  # Happy-Eyeballs outbound requests.
  class FaradayAdapter < Faraday::Adapter::HTTP
    private

    def setup_connection(env)
      # A proxy resolves and dials onward itself (and may be internal), so SSRF filtering
      # cannot apply; connect to it over plain http.rb.
      return super if env[:request] && env[:request][:proxy]

      conn = FinalDestination::HTTPRb
      conn = request_config(conn, env[:request]) if env[:request]
      conn.headers(env.request_headers)
    end
  end
end
