# frozen_string_literal: true

module DiscourseWorkflows
  class WebhooksController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required
    skip_before_action :check_xhr

    def receive
      DiscourseWorkflows::Webhook::Receive.call(
        service_params.deep_merge(params: webhook_params),
      ) do |result|
        on_success { render json: { success: true } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:webhook_nodes) do
          render json: { error: "not_found" }, status: :not_found
        end
      end
    end

    private

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
      if request.content_type&.include?("application/json")
        JSON.parse(request.raw_post).presence || {}
      else
        params.except(:path, :controller, :action, :format).to_unsafe_h
      end
    rescue JSON::ParserError
      {}
    end

    def extract_headers
      request
        .headers
        .env
        .each_with_object({}) do |(key, value), headers|
          if key.start_with?("HTTP_")
            header_name = key.delete_prefix("HTTP_").downcase.tr("_", "-")
            headers[header_name] = value
          end
        end
    end
  end
end
