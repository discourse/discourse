# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariablesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      DiscourseWorkflows::WorkflowVariable::Create.call(service_params) do |result|
        on_success do |variable:, workflow:|
          render json: {
                   variable:
                     DiscourseWorkflows::WorkflowVariableSerializer.new(
                       variable,
                       root: false,
                     ).as_json,
                   workflow:
                     DiscourseWorkflows::WorkflowSerializer.new(workflow, root: false).as_json,
                 },
                 status: :created
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_errors(:variable) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update
      DiscourseWorkflows::WorkflowVariable::Update.call(service_params) do |result|
        on_success do |variable:, workflow:|
          render json: {
                   variable:
                     DiscourseWorkflows::WorkflowVariableSerializer.new(
                       variable,
                       root: false,
                     ).as_json,
                   workflow:
                     DiscourseWorkflows::WorkflowSerializer.new(workflow, root: false).as_json,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:existing_value_compatible_with_new_type) do |policy|
          render(json: failed_json.merge(errors: [policy.reason]), status: :unprocessable_entity)
        end
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
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
      DiscourseWorkflows::WorkflowVariable::Destroy.call(service_params) do |result|
        on_success do |workflow:|
          render json: {
                   workflow:
                     DiscourseWorkflows::WorkflowSerializer.new(workflow, root: false).as_json,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:variable) { raise Discourse::NotFound }
      end
    end

    def update_value
      DiscourseWorkflows::WorkflowVariable::UpdateValue.call(service_params) do |result|
        on_success do |variable:, workflow:|
          render json: {
                   variable:
                     DiscourseWorkflows::WorkflowVariableSerializer.new(
                       variable,
                       root: false,
                     ).as_json,
                   workflow:
                     DiscourseWorkflows::WorkflowSerializer.new(workflow, root: false).as_json,
                 }
        end
        on_failed_step(:activate_triggers) do |step_result|
          render(
            json: failed_json.merge(errors: Array(step_result.error)),
            status: :unprocessable_entity,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:value_is_valid) do |policy|
          render(json: failed_json.merge(errors: [policy.reason]), status: :unprocessable_entity)
        end
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:variable) { raise Discourse::NotFound }
        on_model_errors(:variable) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def import
      DiscourseWorkflows::WorkflowVariable::ImportDefinitions.call(service_params) do |result|
        on_success do |workflow:, imported_variables:|
          render json: {
                   workflow:
                     DiscourseWorkflows::WorkflowSerializer.new(workflow, root: false).as_json,
                   imported_count: imported_variables[:created].size,
                   skipped_keys: imported_variables[:skipped],
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
      end
    end
  end
end
