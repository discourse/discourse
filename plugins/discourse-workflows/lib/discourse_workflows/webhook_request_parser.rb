# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookRequestParser
    MAX_BODY_SIZE = 1.megabyte

    FILTERED_HEADERS = %w[authorization cookie proxy-authorization].to_set.freeze

    RACK_UNPREFIXED_HEADERS = {
      "CONTENT_TYPE" => "content-type",
      "CONTENT_LENGTH" => "content-length",
    }.freeze

    def initialize(request, params)
      @request = request
      @params = params
    end

    def parse_body
      validate_body_size!

      if @request.content_type&.include?("application/json")
        parse_json_body
      else
        @params.except(:path, :controller, :action, :format).to_unsafe_h
      end
    end

    def extract_headers
      @request
        .headers
        .env
        .each_with_object({}) do |(key, value), headers|
          header_name = normalize_header_name(key)
          next unless header_name

          headers[header_name] = FILTERED_HEADERS.include?(header_name) ? "[FILTERED]" : value
        end
    end

    private

    def validate_body_size!
      if (@request.content_length || 0) > MAX_BODY_SIZE
        raise Discourse::InvalidParameters, "Request body too large"
      end
    end

    def parse_json_body
      body = @request.raw_post
      raise Discourse::InvalidParameters, "Request body too large" if body.bytesize > MAX_BODY_SIZE
      JSON.parse(body).presence || {}
    rescue JSON::ParserError
      raise Discourse::InvalidParameters, "Invalid JSON in request body"
    end

    def normalize_header_name(key)
      if key.start_with?("HTTP_")
        key.delete_prefix("HTTP_").downcase.tr("_", "-")
      else
        RACK_UNPREFIXED_HEADERS[key]
      end
    end
  end
end
