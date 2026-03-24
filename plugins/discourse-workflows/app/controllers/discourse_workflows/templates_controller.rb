# frozen_string_literal: true

module DiscourseWorkflows
  class TemplatesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Template::List.call(service_params) do
        on_success { |templates:| render json: { templates: templates } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def show
      DiscourseWorkflows::Template::Show.call(
        service_params.deep_merge(params: { template_id: params[:id] }),
      ) do
        on_success { |template:| render json: { template: template } }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:template) { raise Discourse::NotFound }
      end
    end
  end
end
