# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookResponseBuilder
    def self.immediate(parameters)
      new(parameters).immediate
    end

    def self.last_node(execution, parameters)
      new(parameters).last_node(execution)
    end

    def initialize(parameters)
      @parameters = (parameters || {}).deep_stringify_keys
    end

    def immediate
      WebhookResponse.new(
        body: immediate_body,
        headers: response_headers,
        no_body: immediate_no_body?,
        status_code: response_code,
      )
    end

    def last_node(execution)
      WebhookResponse.new(
        body: last_node_body(execution),
        headers: response_headers,
        no_body: last_node_no_body?,
        status_code: response_code,
      )
    end

    private

    def immediate_body
      return nil if immediate_no_body?

      body = @parameters["response_body"]
      return { success: true } if body.blank?

      parse_json_body(body)
    end

    def last_node_body(execution)
      case @parameters["response_data"].presence || Schemas::Webhook::RESPONSE_DATA_FIRST_ENTRY_JSON
      when Schemas::Webhook::RESPONSE_DATA_ALL_ENTRIES
        last_node_items(execution).map { |item| item["json"] || {} }
      when Schemas::Webhook::RESPONSE_DATA_NO_DATA
        nil
      else
        last_node_items(execution).dig(0, "json")
      end
    end

    def last_node_items(execution)
      last_step = execution.execution_data&.last_step_with_status("success")
      Array.wrap(last_step&.dig("output"))
    end

    def immediate_no_body?
      @parameters["no_response_body"] == true
    end

    def last_node_no_body?
      @parameters["response_data"] == Schemas::Webhook::RESPONSE_DATA_NO_DATA
    end

    def response_code
      (@parameters["response_code"].presence || 200).to_i
    end

    def response_headers
      rows = @parameters.dig("response_headers", "values") || []
      rows.each_with_object({}) do |header, result|
        key = header["key"].to_s
        result[key] = header["value"].to_s if key.present?
      end
    end

    def parse_json_body(body)
      return body unless body.is_a?(String)

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end
  end
end
