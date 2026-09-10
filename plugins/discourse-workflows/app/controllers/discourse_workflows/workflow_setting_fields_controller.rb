# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingFieldsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def create
      DiscourseWorkflows::WorkflowSettingField::Create.call(service_params) do |result|
        on_success do |workflow_setting_field:, workflow:|
          render json: {
                   workflow_setting_field:
                     DiscourseWorkflows::WorkflowSettingFieldSerializer.new(
                       workflow_setting_field,
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
        on_model_errors(:workflow_setting_field) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update
      DiscourseWorkflows::WorkflowSettingField::Update.call(service_params) do |result|
        on_success do |workflow_setting_field:, workflow:|
          render json: {
                   workflow_setting_field:
                     DiscourseWorkflows::WorkflowSettingFieldSerializer.new(
                       workflow_setting_field,
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
        on_model_not_found(:workflow_setting_field) { raise Discourse::NotFound }
        on_model_errors(:workflow_setting_field) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def destroy
      DiscourseWorkflows::WorkflowSettingField::Destroy.call(service_params) do |result|
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
        on_model_not_found(:workflow_setting_field) { raise Discourse::NotFound }
      end
    end

    def update_value
      DiscourseWorkflows::WorkflowSettingField::UpdateValue.call(service_params) do |result|
        on_success do |workflow_setting_field:, workflow:|
          render json: {
                   workflow_setting_field:
                     DiscourseWorkflows::WorkflowSettingFieldSerializer.new(
                       workflow_setting_field,
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
        on_model_not_found(:workflow_setting_field) { raise Discourse::NotFound }
        on_model_errors(:workflow_setting_field) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def import
      DiscourseWorkflows::WorkflowSettingField::ImportDefinitions.call(service_params) do |result|
        on_success do |workflow:, imported_fields:|
          render json: {
                   workflow:
                     DiscourseWorkflows::WorkflowSerializer.new(workflow, root: false).as_json,
                   imported_count: imported_fields[:created].size,
                   skipped_keys: imported_fields[:skipped],
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
