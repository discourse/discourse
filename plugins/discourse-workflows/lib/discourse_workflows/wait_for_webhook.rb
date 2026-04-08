# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForWebhook < WaitForResume
    attr_reader :http_method, :response_mode, :response_code, :timeout_amount, :timeout_unit

    def initialize(
      http_method: "GET",
      response_mode: "immediately",
      response_code: "200",
      timeout_amount: nil,
      timeout_unit: "hours"
    )
      @http_method = http_method
      @response_mode = response_mode
      @response_code = response_code
      @timeout_amount = timeout_amount
      @timeout_unit = timeout_unit
      super(type: :webhook, message: "Workflow paused waiting for webhook callback")
    end

    def timeout_seconds
      return nil if @timeout_amount.nil?
      @timeout_amount.public_send(@timeout_unit).to_i
    end
  end
end
