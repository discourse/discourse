# frozen_string_literal: true

module DiscourseWorkflows
  class VariablesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Variable::List.call(service_params) do |result|
        on_success do |variables:, load_more_url:, total_rows:|
          render json: {
                   variables: serialize_data(variables, DiscourseWorkflows::VariableSerializer),
                   meta: {
                     total_rows_variables: total_rows,
                     load_more_variables: load_more_url,
                   }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def create
      DiscourseWorkflows::Variable::Create.call(
        service_params.deep_merge(params: variable_params),
      ) do |result|
        on_success do |variable:|
          render_serialized(variable, DiscourseWorkflows::VariableSerializer, root: "variable")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
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
        service_params.deep_merge(params: variable_params.merge(variable_id: params[:id])),
      ) do |result|
        on_success do |variable:|
          render_serialized(variable, DiscourseWorkflows::VariableSerializer, root: "variable")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
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
      DiscourseWorkflows::Variable::Delete.call(
        service_params.deep_merge(params: { variable_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:variable) { raise Discourse::NotFound }
      end
    end

    private

    def variable_params
      value = params.slice(:key, :value, :description)
      value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    end
  end
end
