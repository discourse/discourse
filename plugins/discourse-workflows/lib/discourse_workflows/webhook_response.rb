# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookResponse
    attr_reader :body, :headers, :status, :status_code, :workflow_data

    def self.coerce(response)
      return response if response.is_a?(self)

      response = response.to_h.with_indifferent_access
      new(
        body: response[:body],
        headers: response[:headers] || {},
        no_body: response[:no_body] || false,
        status: response[:status],
        status_code: response[:status_code] || response[:status],
      )
    end

    def self.respond(status:, body: {}, headers: {})
      new(body: body, headers: headers, status: status, status_code: status)
    end

    def self.resume(workflow_data:, status: :ok, body: {}, headers: {})
      new(
        body: body,
        headers: headers,
        status: status,
        status_code: status,
        workflow_data: workflow_data,
      )
    end

    def self.success
      new(body: { success: true }, status_code: 200)
    end

    def initialize(
      body: nil,
      headers: {},
      no_body: false,
      status: nil,
      status_code: 200,
      workflow_data: nil
    )
      @body = body
      @headers = headers.to_h.stringify_keys
      @no_body = no_body
      @status_code = sanitize_status_code(status_code || status)
      @status = status || @status_code
      @workflow_data = workflow_data
    end

    def location
      headers["Location"] || headers["location"]
    end

    def redirect?
      location.present? && (300..399).cover?(status_code)
    end

    def no_body?
      @no_body
    end

    def resume?
      workflow_data.present?
    end

    def text?
      headers["Content-Type"].to_s.start_with?("text/plain") ||
        headers["content-type"].to_s.start_with?("text/plain")
    end

    private

    def sanitize_status_code(code)
      status = Rack::Utils.status_code(code.presence || 200)
      (200..599).cover?(status) ? status : 200
    end
  end
end
