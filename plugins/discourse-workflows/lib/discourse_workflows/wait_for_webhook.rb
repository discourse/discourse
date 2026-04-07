# frozen_string_literal: true

module DiscourseWorkflows
  class WaitForWebhook < WaitForResume
    attr_reader :http_method, :response_mode, :response_code

    def initialize(http_method: "GET", response_mode: "immediately", response_code: "200")
      @http_method = http_method
      @response_mode = response_mode
      @response_code = response_code
      super(type: :webhook, message: "Workflow paused waiting for webhook callback")
    end
  end
end
