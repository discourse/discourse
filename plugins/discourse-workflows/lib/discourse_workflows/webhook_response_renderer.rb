# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookResponseRenderer
    def self.render(controller, response)
      new(controller, WebhookResponse.coerce(response)).render
    end

    def initialize(controller, response)
      @controller = controller
      @response = response
    end

    def render
      apply_headers

      if @response.redirect?
        @controller.redirect_to @response.location,
                                status: @response.status_code,
                                allow_other_host: true
      elsif @response.no_body?
        @controller.head @response.status_code
      elsif @response.text?
        @controller.render plain: @response.body.to_s, status: @response.status_code
      else
        @controller.render json: @response.body, status: @response.status_code
      end
    end

    private

    def apply_headers
      @response.headers.each { |key, value| @controller.response.headers[key] = value }
    end
  end
end
