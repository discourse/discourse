# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTestsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    before_action :enforce_simulation_quota, only: %i[run refresh]

    def index
      DiscourseWorkflows::WorkflowTest::List.call(service_params) do |result|
        on_success do |workflow_tests:|
          render json: {
                   tests:
                     serialize_data(workflow_tests, DiscourseWorkflows::WorkflowTestListSerializer),
                 }
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
      end
    end

    def show
      DiscourseWorkflows::WorkflowTest::Show.call(service_params) do |result|
        on_success { |workflow_test:| render_test(workflow_test) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:workflow_test) { raise Discourse::NotFound }
      end
    end

    def create
      DiscourseWorkflows::WorkflowTest::Create.call(service_params) do |result|
        on_success { |workflow_test:| render_test(workflow_test, status: :created) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_failed_policy(:source_has_input) { render_policy_error("source_has_no_input") }
        on_failed_policy(:within_test_limit) do
          render_policy_error(
            "too_many_tests",
            limit: DiscourseWorkflows::WorkflowTest::MAX_PER_WORKFLOW,
          )
        end
        on_failed_contract { |contract| render_contract_errors(contract) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:source_execution) { raise Discourse::NotFound }
        on_model_not_found(:trigger_node) { render_policy_error("source_has_no_input") }
        on_model_errors(:workflow_test) { |model| render_model_errors(model) }
      end
    end

    def update
      DiscourseWorkflows::WorkflowTest::Update.call(service_params) do |result|
        on_success { |workflow_test:| render_test(workflow_test) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_failed_policy(:pasted_steps_exist) { render_policy_error("unknown_pasted_step") }
        on_failed_policy(:pasted_items_are_valid) { render_policy_error("invalid_pasted_response") }
        on_failed_contract { |contract| render_contract_errors(contract) }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:workflow_test) { raise Discourse::NotFound }
        on_model_errors(:workflow_test) { |model| render_model_errors(model) }
      end
    end

    def destroy
      DiscourseWorkflows::WorkflowTest::Destroy.call(service_params) do |result|
        on_success { head :no_content }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:workflow_test) { raise Discourse::NotFound }
      end
    end

    def run
      DiscourseWorkflows::WorkflowTest::Run.call(service_params) do |result|
        on_success do |executions:|
          render json: {
                   executions:
                     executions.map { |execution|
                       { id: execution.id, workflow_test_id: execution.workflow_test_id }
                     },
                 },
                 status: :created
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_failed_policy(:tests_have_checks) { render_policy_error("checks_required") }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:workflow_tests) { raise Discourse::NotFound }
      end
    end

    def refresh
      DiscourseWorkflows::WorkflowTest::RefreshData.call(service_params) do |result|
        on_success do |execution:|
          render json: {
                   execution: {
                     id: execution.id,
                     workflow_test_id: execution.workflow_test_id,
                   },
                 },
                 status: :created
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
        on_failed_policy(:can_manage_workflows) { raise Discourse::InvalidAccess }
        on_failed_policy(:workflow_tests_enabled) { raise Discourse::NotFound }
        on_failed_policy(:test_has_checks) { render_policy_error("checks_required") }
        on_model_not_found(:workflow) { raise Discourse::NotFound }
        on_model_not_found(:workflow_test) { raise Discourse::NotFound }
      end
    end

    private

    def render_test(workflow_test, status: :ok)
      render json: {
               test:
                 DiscourseWorkflows::WorkflowTestSerializer.new(workflow_test, root: false).as_json,
             },
             status:
    end

    def render_policy_error(key, **params)
      render(
        json:
          failed_json.merge(errors: [I18n.t("discourse_workflows.tests.errors.#{key}", **params)]),
        status: :unprocessable_entity,
      )
    end

    def render_contract_errors(contract)
      render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
    end

    def render_model_errors(model)
      render(
        json: failed_json.merge(errors: model.errors.full_messages),
        status: :unprocessable_entity,
      )
    end

    def enforce_simulation_quota
      RateLimiter.new(
        current_user,
        "discourse-workflows-simulations",
        SiteSetting.discourse_workflows_max_simulations_per_hour,
        1.hour,
        apply_limit_to_staff: true,
      ).performed!
    end
  end
end
