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

    MAX_WEBHOOK_BODY_SIZE = 1.megabyte

    def receive
      DiscourseWorkflows::Webhook::Receive.call(
        service_params.deep_merge(params: webhook_params),
      ) do |result|
        on_success do
          if result[:all_nodes_rejected_auth]
            response.headers["WWW-Authenticate"] = 'Basic realm="Webhook"'
            render json: { error: "unauthorized" }, status: :unauthorized
          elsif result[:sync_execution]
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
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def render_sync_response(result)
      execution = result[:sync_execution]
      response_mode = result[:sync_response_mode]

      if response_mode == "respond_to_webhook"
        render_respond_to_webhook(execution)
      elsif response_mode == "when_last_node_finishes"
        render_last_node_output(execution, result[:sync_response_code])
      end
    end

    def render_respond_to_webhook(execution)
      step = execution.steps.where(node_type: "action:respond_to_webhook").order(:position).last
      return render json: { success: true } unless step&.output&.first

      output = step.output.first["json"]
      response_type = output["response_type"]
      status_code = sanitize_status_code(output["status_code"])
      custom_headers = output["headers"] || {}

      custom_headers.each do |key, value|
        next if BLOCKED_RESPONSE_HEADERS.include?(key.to_s.downcase)
        response.headers[key] = value
      end

      case response_type
      when "redirect"
        redirect_to output["redirect_url"], status: status_code, allow_other_host: true
      when "json"
        body = output["response_body"]
        parsed =
          if body.is_a?(String)
            begin
              JSON.parse(body)
            rescue StandardError
              body
            end
          else
            body
          end
        render json: parsed, status: status_code
      when "text"
        render plain: output["response_body"], status: status_code
      when "no_data"
        head status_code
      else
        render json: { success: true }
      end
    end

    def render_last_node_output(execution, response_code)
      status = sanitize_status_code(response_code)
      last_step = execution.steps.where(status: :success).order(:position).last
      output = last_step&.output&.first&.dig("json")

      if output.present?
        render json: output, status: status
      else
        head status
      end
    end

    def webhook_params
      {
        path: params[:path],
        http_method: request.method,
        body: parse_body,
        headers: extract_headers,
        query_params: request.query_parameters,
      }
    end

    def parse_body
      if request.content_length.to_i > MAX_WEBHOOK_BODY_SIZE
        raise Discourse::InvalidParameters, "Request body too large"
      end

      if request.content_type&.include?("application/json")
        JSON.parse(request.raw_post).presence || {}
      else
        params.except(:path, :controller, :action, :format).to_unsafe_h
      end
    rescue JSON::ParserError
      {}
    end

    FILTERED_INCOMING_HEADERS = %w[authorization cookie proxy-authorization].to_set.freeze

    def extract_headers
      request
        .headers
        .env
        .each_with_object({}) do |(key, value), headers|
          if key.start_with?("HTTP_")
            header_name = key.delete_prefix("HTTP_").downcase.tr("_", "-")
            if FILTERED_INCOMING_HEADERS.include?(header_name)
              headers[header_name] = "[FILTERED]"
            else
              headers[header_name] = value
            end
          end
        end
    end

    def sanitize_status_code(code)
      status = (code.presence || 200).to_i
      (200..599).cover?(status) ? status : 200
    end
  end
end
