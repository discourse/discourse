# frozen_string_literal: true

module DiscourseWorkflows
  class WebhooksController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required
    skip_before_action :check_xhr

    BLOCKED_RESPONSE_HEADERS = %w[
      set-cookie
      content-security-policy
      content-security-policy-report-only
      x-frame-options
      access-control-allow-origin
      access-control-allow-credentials
      access-control-allow-methods
      access-control-allow-headers
      strict-transport-security
      transfer-encoding
      host
      connection
    ].to_set.freeze

    WEBHOOK_RATE_LIMIT = 20
    WEBHOOK_RATE_PERIOD = 10

    before_action :check_webhook_rate_limit, only: [:receive]

    def receive
      DiscourseWorkflows::Webhook::Receive.call(
        service_params.deep_merge(params: webhook_params),
      ) do |result|
        on_success do
          if result[:sync_execution]
            render_sync_response(result)
          else
            render json: { success: true }
          end
        end
        on_model_not_found(:webhook_nodes) do
          render json: { error: "not_found" }, status: :not_found
        end
        on_failed_step(:validate_waiting_http_method) do
          render json: { error: "not_found" }, status: :not_found
        end
        on_model_not_found(:authenticated_nodes) do
          response.headers["WWW-Authenticate"] = 'Basic realm="Webhook"'
          render json: { error: "unauthorized" }, status: :unauthorized
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def render_sync_response(result)
      case result[:sync_response_mode]
      when Schemas::Webhook::RESPONSE_MODE_RESPOND_TO_WEBHOOK
        render_respond_to_webhook(result[:sync_execution])
      when Schemas::Webhook::RESPONSE_MODE_WHEN_LAST_NODE
        render_last_node_output(result[:sync_execution], result[:sync_response_code])
      end
    end

    def render_respond_to_webhook(execution)
      step = find_last_respond_step(execution)
      return render json: { success: true } unless step

      output = step["output"].first["json"]
      apply_custom_headers(output["headers"])
      render_webhook_response(output)
    end

    def find_last_respond_step(execution)
      steps = execution.execution_data&.find_steps_by_type("action:respond_to_webhook") || []
      step = steps.max_by { |s| s["position"] || 0 }
      step if step&.dig("output", 0)
    end

    def apply_custom_headers(headers)
      (headers || {}).each do |key, value|
        next if BLOCKED_RESPONSE_HEADERS.include?(key.to_s.downcase)
        response.headers[key] = value
      end
    end

    def render_webhook_response(output)
      status_code = sanitize_status_code(output["status_code"])

      case output["response_type"]
      when "redirect"
        render_webhook_redirect(output["redirect_url"], status_code)
      when "json"
        render json: parse_json_body(output["response_body"]), status: status_code
      when "text"
        render plain: output["response_body"], status: status_code
      when "no_data"
        head status_code
      else
        render json: { success: true }
      end
    end

    def render_webhook_redirect(url, status_code)
      unless valid_redirect_url?(url)
        return render json: { error: "invalid_redirect_url" }, status: :bad_request
      end
      redirect_to url, status: status_code, allow_other_host: true
    end

    def parse_json_body(body)
      return body unless body.is_a?(String)
      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def render_last_node_output(execution, response_code)
      status = sanitize_status_code(response_code)
      last_step = execution.execution_data&.last_step_with_status("success")
      output = last_step&.dig("output", 0, "json")

      if output.present?
        render json: output, status: status
      else
        head status
      end
    end

    def check_webhook_rate_limit
      key = "workflow_webhook:#{request.ip}"
      limiter = RateLimiter.new(nil, key, WEBHOOK_RATE_LIMIT, WEBHOOK_RATE_PERIOD)
      unless limiter.performed!(raise_error: false)
        render json: { error: "rate_limit" }, status: :too_many_requests
      end
    end

    def webhook_params
      parser = WebhookRequestParser.new(request, params)
      {
        path: params[:path],
        http_method: request.method,
        body: parser.parse_body,
        headers: parser.extract_headers,
        query_params: request.query_parameters,
        raw_authorization: request.headers["Authorization"],
      }
    end

    def valid_redirect_url?(url)
      return false if url.blank?
      uri = URI.parse(url)
      uri.scheme.in?(%w[http https]) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    def sanitize_status_code(code)
      status = (code.presence || 200).to_i
      (200..599).cover?(status) ? status : 200
    end
  end
end
