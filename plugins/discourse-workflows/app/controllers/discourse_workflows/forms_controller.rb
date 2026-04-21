# frozen_string_literal: true

module DiscourseWorkflows
  class FormsController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required
    skip_before_action :check_xhr

    before_action :check_form_submit_rate_limit, only: :create
    before_action :check_form_resume_rate_limit, only: :update
    before_action :verify_request_origin, only: %i[create update]

    def show
      if request.format.json?
        DiscourseWorkflows::Form::Show.call(service_params) do
          on_success { |form_data:| render json: form_data }
          on_failed_policy(:authenticated_if_required) { raise Discourse::NotLoggedIn }
          on_failure { render(json: failed_json, status: :unprocessable_entity) }
          on_model_not_found(:workflow) { raise Discourse::NotFound }
          on_model_not_found(:form_node) { raise Discourse::NotFound }
        end
      else
        render html: "", layout: "application"
      end
    end

    def create
      DiscourseWorkflows::Form::Submit.call(service_params) do
        on_success do |execution:, response_metadata:|
          resume_token = execution&.execution_data&.context_data&.dig("__resume_token")
          render json: {
                   resume_token: resume_token,
                   has_downstream_form: response_metadata[:has_downstream_form],
                   response_mode: response_metadata[:response_mode],
                   form_channel:
                     DiscourseWorkflows::Executor.form_channel(execution&.id, resume_token),
                 }
        end
        on_failed_policy(:authenticated_if_required) { raise Discourse::NotLoggedIn }
        on_failed_step(:validate_required_form_fields) do |missing_fields:|
          render json: { errors: missing_fields }, status: :unprocessable_entity
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:trigger_node) { raise Discourse::NotFound }
      end
    end

    def update
      DiscourseWorkflows::Form::Resume.call(service_params) do
        on_success do |execution:|
          render json: {
                   resume_token: execution.execution_data&.context_data&.dig("__resume_token"),
                 }
        end
        on_failed_step(:validate_required_form_fields) do |missing_fields:|
          render json: { errors: missing_fields }, status: :unprocessable_entity
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:execution) { raise Discourse::NotFound }
        on_model_not_found(:waiting_node) { raise Discourse::NotFound }
      end
    end

    private

    def check_form_submit_rate_limit
      RateLimiter.new(current_user, "workflow_form_submit:#{request.remote_ip}", 10, 60).performed!
    end

    def check_form_resume_rate_limit
      RateLimiter.new(current_user, "workflow_form_resume:#{request.remote_ip}", 10, 60).performed!
    end

    def verify_request_origin
      origin = request.origin || request.headers["Origin"]
      referer = request.referer

      expected_host = Discourse.current_hostname
      return if origin.present? && URI.parse(origin).host == expected_host
      return if referer.present? && URI.parse(referer).host == expected_host

      raise Discourse::InvalidAccess
    rescue URI::InvalidURIError
      raise Discourse::InvalidAccess
    end
  end
end
