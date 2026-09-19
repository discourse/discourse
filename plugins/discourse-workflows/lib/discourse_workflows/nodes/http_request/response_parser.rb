# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class ResponseParser
        MAX_RESPONSE_BODY_SIZE = 1.megabyte
        MAX_ALLOWED_SIZE = 10.megabytes

        def self.parse(response, max_size_kb: nil, log: nil)
          max_size =
            if max_size_kb
              max_size_kb.to_i.kilobytes.clamp(1.kilobyte, MAX_ALLOWED_SIZE)
            else
              MAX_RESPONSE_BODY_SIZE
            end
          {
            status: response.status,
            status_message: response.respond_to?(:reason_phrase) ? response.reason_phrase : nil,
            headers: response.headers.to_h,
            body: parse_body(response, max_size, log),
          }
        end

        def self.parse_body(response, max_size, log)
          content_type = response.headers["content-type"] || ""
          body = truncate_body(response.body, max_size, log)

          if content_type.include?("application/json")
            JSON.parse(body)
          else
            { "data" => body }
          end
        rescue JSON::ParserError
          { "data" => body }
        end

        def self.truncate_body(raw_body, max_size, log)
          if raw_body.is_a?(String) && raw_body.bytesize > max_size
            log&.warn(
              "Response body truncated from #{raw_body.bytesize} bytes to #{max_size} bytes",
            )
            raw_body.scrub("").byteslice(0, max_size).scrub("")
          else
            raw_body.to_s
          end
        end

        private_class_method :parse_body, :truncate_body
      end
    end
  end
end
