# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module HttpRequest
      class ResponseParser
        MAX_RESPONSE_BODY_SIZE = 1.megabyte

        def self.parse(response)
          { status: response.status, headers: response.headers.to_h, body: parse_body(response) }
        end

        def self.parse_body(response)
          content_type = response.headers["content-type"] || ""
          body = truncate_body(response.body)

          if content_type.include?("application/json")
            JSON.parse(body)
          else
            { "data" => body }
          end
        rescue JSON::ParserError
          { "data" => body }
        end

        def self.truncate_body(raw_body)
          if raw_body.is_a?(String) && raw_body.bytesize > MAX_RESPONSE_BODY_SIZE
            raw_body.byteslice(0, MAX_RESPONSE_BODY_SIZE).scrub("")
          else
            raw_body.to_s
          end
        end

        private_class_method :parse_body, :truncate_body
      end
    end
  end
end
