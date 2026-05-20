# frozen_string_literal: true

require "json"

# Rack app that echoes every request back as a JSON response. Tests use it
# to assert on what nginx forwards upstream: method, path, query string,
# request headers, body.
#
# Per-request response shaping is available via request headers prefixed
# with `X-Mock-`:
#
#   X-Mock-Status: 503     -> respond with the given status code
#   X-Mock-Body: <text>    -> respond with the given body instead of the echo
#   X-Mock-Header-Foo: bar -> add `Foo: bar` to the response headers
#
# These let individual tests provoke specific upstream behavior without
# adding a new Rack route every time.
module Nginx
  module Support
    class MockUpstream
      ECHO_HEADER_PREFIX = "HTTP_"
      MOCK_HEADER_PREFIX = "HTTP_X_MOCK_"
      MOCK_RESPONSE_HEADER_PREFIX = "HTTP_X_MOCK_HEADER_"

      def call(env)
        status = mock_status(env)
        headers = { "Content-Type" => "application/json" }
        merge_mock_headers!(headers, env)

        body =
          if env["HTTP_X_MOCK_BODY"]
            env["HTTP_X_MOCK_BODY"]
          else
            JSON.dump(echo_payload(env))
          end

        [status, headers, [body]]
      end

      private

      def mock_status(env)
        env["HTTP_X_MOCK_STATUS"]&.to_i || 200
      end

      def merge_mock_headers!(headers, env)
        env.each do |key, value|
          next unless key.start_with?(MOCK_RESPONSE_HEADER_PREFIX)
          header_name =
            key.sub(MOCK_RESPONSE_HEADER_PREFIX, "").split("_").map(&:capitalize).join("-")
          headers[header_name] = value
        end
      end

      def echo_payload(env)
        request_headers = {}
        env.each do |key, value|
          next unless key.start_with?(ECHO_HEADER_PREFIX)
          # Skip Mock-* control headers — they aren't part of what nginx forwarded
          next if key.start_with?(MOCK_HEADER_PREFIX)
          name = key.sub(ECHO_HEADER_PREFIX, "").split("_").map(&:capitalize).join("-")
          request_headers[name] = value
        end

        body = env["rack.input"]&.read || ""
        env["rack.input"]&.rewind

        {
          method: env["REQUEST_METHOD"],
          path: env["PATH_INFO"],
          query: env["QUERY_STRING"],
          headers: request_headers,
          body: body,
        }
      end
    end
  end
end
