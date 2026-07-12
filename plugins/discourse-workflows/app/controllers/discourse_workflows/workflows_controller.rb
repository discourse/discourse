# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowsController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      DiscourseWorkflows::Workflow::List.call(service_params) do |result|
        on_success do |workflows:, total_rows:, load_more_url:|
          render json: {
                   workflows: serialize_data(workflows, DiscourseWorkflows::WorkflowSerializer),
                   meta: {
                     total_rows_workflows: total_rows,
                     load_more_workflows: load_more_url,
                   }.compact,
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def show
      DiscourseWorkflows::Workflow::Show.call(
        service_params.deep_merge(params: { workflow_id: params[:id] }),
      ) do |result|
        on_success do |workflow:|
          render_serialized(workflow, DiscourseWorkflows::WorkflowSerializer, root: "workflow")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
      end
    end

    def create
      DiscourseWorkflows::Workflow::Create.call(
        service_params.deep_merge(params: workflow_params),
      ) do |result|
        on_success do |workflow:|
          render_serialized(
            workflow,
            DiscourseWorkflows::WorkflowSerializer,
            root: "workflow",
            status: :created,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_step(:populate_graph) do |step_result|
          render(
            json: failed_json.merge(errors: Array(step_result.error)),
            status: :unprocessable_entity,
          )
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:workflow) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update
      workflow_attrs = workflow_params

      if workflow_attrs.key?("published") &&
           workflow_attrs.keys.all? { |key| %w[name published].include?(key) }
        return update_published_state(workflow_attrs["published"])
      end

      DiscourseWorkflows::Workflow::Update.call(
        service_params.deep_merge(params: workflow_attrs.merge(workflow_id: params[:id])),
      ) do |result|
        on_success do |workflow:|
          render_serialized(workflow, DiscourseWorkflows::WorkflowSerializer, root: "workflow")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_step(:populate_graph) do |step_result|
          render(
            json: failed_json.merge(errors: Array(step_result.error)),
            status: :unprocessable_entity,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:workflow) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def destroy
      DiscourseWorkflows::Workflow::Destroy.call(
        service_params.deep_merge(params: { workflow_id: params[:id] }),
      ) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_not_called_by_other_workflows) do
          render(
            json:
              failed_json.merge(
                type: "workflow_called_by_other_workflows",
                referencing_workflows: result[:referencing_workflows],
              ),
            status: :unprocessable_entity,
          )
        end
      end
    end

    def update_pin_data
      service_input = { workflow_id: params[:id], node_name: params[:node_name] }
      service_input[:items] = unwrap_pin_data_items(params[:items]) if params.key?(:items)

      DiscourseWorkflows::Workflow::UpdatePinData.call(
        service_params.deep_merge(params: service_input),
      ) do |result|
        on_success { head :no_content }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:node) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:node_supports_pinning) do
          render(
            json:
              failed_json.merge(
                errors: [I18n.t("discourse_workflows.pin_data.errors.unsupported_node")],
              ),
            status: :unprocessable_entity,
          )
        end
        on_failed_policy(:within_size_cap) do
          render(
            json:
              failed_json.merge(
                errors: [
                  I18n.t(
                    "discourse_workflows.pin_data.errors.size_limit_exceeded",
                    limit: SiteSetting.discourse_workflows_max_pin_data_bytes,
                  ),
                ],
              ),
            status: :unprocessable_entity,
          )
        end
        on_failed_policy(:items_are_valid) do
          render(
            json:
              failed_json.merge(
                errors: [I18n.t("discourse_workflows.pin_data.errors.invalid_items")],
              ),
            status: :unprocessable_entity,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def discard_draft
      DiscourseWorkflows::Workflow::DiscardDraft.call(
        service_params.deep_merge(params: { workflow_id: params[:id] }),
      ) do |result|
        on_success do |workflow:|
          render_serialized(workflow, DiscourseWorkflows::WorkflowSerializer, root: "workflow")
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:active_version) do
          render(json: failed_json, status: :unprocessable_entity)
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:workflow) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end

    private

    def workflow_params
      params.require(:workflow).to_unsafe_h
    end

    def unwrap_pin_data_items(raw)
      case raw
      when ActionController::Parameters
        raw.to_unsafe_h
      when Array
        raw.map { |item| unwrap_pin_data_items(item) }
      else
        raw
      end
    end

    def update_published_state(published)
      service_class =
        ActiveModel::Type::Boolean.new.cast(published) ? Workflow::Publish : Workflow::Unpublish

      service_class.call(service_params.deep_merge(params: { workflow_id: params[:id] })) do
        on_success do |workflow:|
          render_serialized(workflow, DiscourseWorkflows::WorkflowSerializer, root: "workflow")
        end
        on_failed_step(:activate_triggers) do |step_result|
          render(
            json: failed_json.merge(errors: Array(step_result.error)),
            status: :unprocessable_entity,
          )
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:workflow_version) do
          render(json: failed_json, status: :unprocessable_entity)
        end
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_model_errors(:workflow) do |model|
          render(
            json: failed_json.merge(errors: model.errors.full_messages),
            status: :unprocessable_entity,
          )
        end
      end
    end
  end
end
