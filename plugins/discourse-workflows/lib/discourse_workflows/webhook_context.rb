# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookContext
    attr_reader :request, :response, :resume_items, :path_params

    def initialize(request:, path_params: {})
      @request = request
      @response = nil
      @resume_items = nil
      @path_params = path_params
    end

    def apply_path_params(path_params)
      @path_params = path_params || {}
      @request =
        WebhookRequest.new(
          method: request.method,
          path: request.path,
          headers: request.headers,
          params: @path_params,
          query: request.query,
          body: request.body,
          raw_body: request.raw_body,
          ip: request.ip,
          ips: request.ips,
          webhook_url: request.webhook_url,
        )
    end

    def respond(response)
      return false if responded?

      @response = WebhookResponse.coerce(response)
      true
    end

    def responded?
      response.present?
    end

    def resume(items)
      return false if resumed?

      @resume_items = items
      true
    end

    def resumed?
      !resume_items.nil?
    end
  end
end
