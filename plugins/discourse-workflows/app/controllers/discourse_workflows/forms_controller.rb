# frozen_string_literal: true

module DiscourseWorkflows
  class FormsController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required
    skip_before_action :check_xhr

    def show
      if request.format.json?
        DiscourseWorkflows::Form::Show.call(
          service_params.deep_merge(params: { uuid: params[:uuid] }),
        ) do
          on_success { |form_data:| render json: form_data }
          on_failure { render(json: failed_json, status: :unprocessable_entity) }
          on_model_not_found(:form_node) { raise Discourse::NotFound }
        end
      else
        render html: "", layout: "application"
      end
    end

    def create
      DiscourseWorkflows::Form::Submit.call(
        service_params.deep_merge(
          params: {
            uuid: params[:uuid],
            form_data: params[:form_data]&.to_unsafe_h,
          },
        ),
      ) do
        on_success do |execution:, has_downstream_form:, response_mode:|
          render json: {
                   execution_id: execution&.id,
                   has_downstream_form: has_downstream_form,
                   response_mode: response_mode,
                   form_channel: DiscourseWorkflows::Executor.form_channel(execution&.id),
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:trigger_node) { raise Discourse::NotFound }
      end
    end

    def update
      DiscourseWorkflows::Form::Resume.call(
        service_params.deep_merge(
          params: {
            execution_id: params[:execution_id],
            form_data: params[:form_data]&.to_unsafe_h,
          },
        ),
      ) do
        on_success { |execution:| render json: { execution_id: execution.id } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:execution) { raise Discourse::NotFound }
        on_model_not_found(:waiting_node) { raise Discourse::NotFound }
      end
    end
  end
end
