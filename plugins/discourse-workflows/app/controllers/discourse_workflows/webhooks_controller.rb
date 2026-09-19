# frozen_string_literal: true

module DiscourseWorkflows
  class WebhooksController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required
    skip_before_action :check_xhr

    WEBHOOK_RATE_LIMIT = 20
    WEBHOOK_RATE_PERIOD = 10

    before_action :check_webhook_rate_limit, only: %i[receive receive_test]

    def receive
      receive_webhook(test_webhook: false)
    end

    def receive_test
      receive_webhook(test_webhook: true)
    end

    private

    def receive_webhook(test_webhook:)
      DiscourseWorkflows::Webhook::Receive.call(
        service_params.deep_merge(params: webhook_params(test_webhook: test_webhook)),
      ) do |result|
        on_success do
          DiscourseWorkflows::WebhookResponseRenderer.render(self, result[:webhook_response])
        end
        on_model_not_found(:webhook_test_listener) do
          render json: { error: "not_found" }, status: :not_found
        end
        on_model_not_found(:claimed_webhook_test_listener) do
          render json: { error: "not_found" }, status: :not_found
        end
        on_model_not_found(:webhook_nodes) do
          render json: { error: "not_found" }, status: :not_found
        end
        on_failed_policy(:valid_resume_request) do
          render json: { error: "not_found" }, status: :not_found
        end
        on_failed_policy(:valid_http_method) do
          render json: { error: "not_found" }, status: :not_found
        end
        on_model_not_found(:authenticated_nodes) do
          render_auth_failure(result[:auth_failure_reason], result[:auth_failure_mode])
        end
        on_model_not_found(:request_allowed_nodes) do
          render json: { error: "forbidden" }, status: :forbidden
        end
        on_model_not_found(:claimed_execution) do
          render json: {
                   error: I18n.t("discourse_workflows.errors.already_resumed"),
                 },
                 status: :conflict
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def render_auth_failure(reason, auth_mode)
      if auth_mode == Webhook::Action::AuthenticateNode::BASIC_AUTH &&
           reason != Webhook::Action::AuthenticateNode::MISCONFIGURED
        response.headers["WWW-Authenticate"] = 'Basic realm="Webhook"'
      end

      case reason
      when Webhook::Action::AuthenticateNode::CHALLENGE
        render plain: "Authorization is required!", status: :unauthorized
      when Webhook::Action::AuthenticateNode::DENIED
        render plain: "Authorization data is wrong!", status: :forbidden
      else
        render plain: "No authentication data defined on node!", status: :internal_server_error
      end
    end

    def check_webhook_rate_limit
      key = "workflow_webhook:#{request.remote_ip}"
      limiter = RateLimiter.new(nil, key, WEBHOOK_RATE_LIMIT, WEBHOOK_RATE_PERIOD)
      unless limiter.performed!(raise_error: false)
        render json: { error: "rate_limit" }, status: :too_many_requests
      end
    end

    def webhook_params(test_webhook:)
      parser = WebhookRequestParser.new(request, params)
      is_resume = params[:execution_id].present?
      query = request.query_parameters
      {
        execution_id: params[:execution_id]&.to_i,
        token: is_resume ? query["signature"] : query["token"],
        webhook_suffix: params[:suffix].to_s,
        path: params[:path].to_s,
        test_listener_id: params[:listener_id].to_s,
        http_method: request.method,
        body: parser.parse_body,
        headers: parser.extract_headers,
        path_params: {
        },
        query_params: is_resume ? query.except("signature") : query,
        raw_body: request.raw_post,
        remote_ip: request.remote_ip,
        ips: request.respond_to?(:ips) ? request.ips : [],
        raw_authorization: request.headers["Authorization"],
        test_webhook: test_webhook,
      }
    end
  end
end
