# frozen_string_literal: true

module DiscourseWorkflows
  class VariablesController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Variable::List.call(service_params) do |result|
        on_success do |variables:, total_rows:, load_more_url:|
          render json: {
                   variables: serialize_data(variables, DiscourseWorkflows::VariableSerializer),
                   meta: { total_rows: total_rows, load_more_url: load_more_url }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def create
      DiscourseWorkflows::Variable::Create.call(service_params) do |result|
        on_success do |variable:|
          render_serialized(
            variable,
            DiscourseWorkflows::VariableSerializer,
            root: "variable",
            status: :created,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_errors(:variable) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update
      DiscourseWorkflows::Variable::Update.call(
        service_params.deep_merge(params: { variable_id: params[:id] }),
      ) do |result|
        on_success do |variable:|
          render_serialized(variable, DiscourseWorkflows::VariableSerializer, root: "variable")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:variable) { raise Discourse::NotFound }
        on_model_errors(:variable) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def destroy
      DiscourseWorkflows::Variable::Destroy.call(
        service_params.deep_merge(params: { variable_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_not_found(:variable) { raise Discourse::NotFound }
      end
    end
  end
end
