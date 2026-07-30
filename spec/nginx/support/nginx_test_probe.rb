# frozen_string_literal: true

module Nginx
  module Support
    class NginxTestProbe
      RESPONSE_HEADERS = {
        "Set-Cookie" => "_t=secret-session; path=/",
        "X-Discourse-Username" => "admin",
        "X-Runtime" => "0.123456",
      }.freeze

      def initialize(app)
        @app = app
        @requests = {}
        @mutex = Mutex.new
      end

      def call(env)
        record_request(env)
        status, headers, body = @app.call(env)

        if env["HTTP_X_NGINX_TEST_INJECT_RESPONSE_HEADERS"] == "true"
          headers = headers.merge(RESPONSE_HEADERS)
        end

        [status, headers, body]
      end

      def request(request_id)
        @mutex.synchronize { @requests.fetch(request_id) }
      end

      def clear
        @mutex.synchronize { @requests.clear }
      end

      private

      def record_request(env)
        request_id = env["HTTP_X_NGINX_TEST_ID"]
        return if request_id.blank?

        request = {
          method: env["REQUEST_METHOD"],
          path: env["PATH_INFO"],
          remote_addr: env["REMOTE_ADDR"],
          headers: env.select { |key, _value| key.start_with?("HTTP_") },
        }
        @mutex.synchronize { @requests[request_id] = request }
      end
    end
  end
end
