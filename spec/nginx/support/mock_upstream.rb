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
      ORIGINAL_HEADER_NAMES_ENV = "nginx.mock_upstream.original_header_names"
      HEADER_WORDS = {
        "CDN" => "CDN",
        "DNT" => "DNT",
        "ETAG" => "ETag",
        "HTTP" => "HTTP",
        "HTTPS" => "HTTPS",
        "ID" => "ID",
        "IP" => "IP",
        "MD5" => "MD5",
        "SSL" => "SSL",
        "TLS" => "TLS",
        "URI" => "URI",
        "URL" => "URL",
        "WWW" => "WWW",
      }.freeze

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
          headers[header_name_from_env_key(key, MOCK_RESPONSE_HEADER_PREFIX)] = value
        end
      end

      def echo_payload(env)
        request_headers = {}
        original_header_names = env[ORIGINAL_HEADER_NAMES_ENV] || {}
        env.each do |key, value|
          next unless key.start_with?(ECHO_HEADER_PREFIX)
          # Skip Mock-* control headers — they aren't part of what nginx forwarded
          next if key.start_with?(MOCK_HEADER_PREFIX)
          name = original_header_names[key] || header_name_from_env_key(key, ECHO_HEADER_PREFIX)
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

      def header_name_from_env_key(key, prefix)
        key
          .delete_prefix(prefix)
          .split("_")
          .map { |part| HEADER_WORDS.fetch(part, part.capitalize) }
          .join("-")
      end
    end
  end
end
