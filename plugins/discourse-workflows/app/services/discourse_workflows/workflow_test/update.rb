# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest::Update
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :test_id, :integer
      attribute :name, :string
      attribute :checks
      attribute :pasted_responses

      validates :workflow_id, :test_id, presence: true
      validates :name, length: { maximum: 100 }, allow_nil: true
      validate :pasted_responses_is_a_hash

      def pasted_responses_is_a_hash
        return if pasted_responses.nil? || pasted_responses.respond_to?(:to_h)

        errors.add(:pasted_responses, :invalid)
      end

      def pasted_items
        return if pasted_responses.nil?

        pasted_responses.to_h.to_h do |node_name, response|
          [node_name.to_s, WorkflowTest::PastedResponse.items_for(response)]
        end
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    policy :workflow_tests_enabled, class_name: Policy::WorkflowTestsEnabled

    lock(:workflow_id) do
      model :workflow
      model :workflow_test
      policy :pasted_steps_exist
      policy :pasted_items_are_valid

      transaction { model :workflow_test, :update_workflow_test }
    end

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_test(workflow:, params:)
      workflow.workflow_tests.find_by(id: params.test_id)
    end

    def pasted_steps_exist(workflow:, params:)
      return true if params.pasted_items.nil?

      node_names = workflow.nodes.map { |node| node["name"].to_s }
      params.pasted_items.keys.all? { |node_name| node_names.include?(node_name) }
    end

    def pasted_items_are_valid(params:)
      return true if params.pasted_items.nil?

      params.pasted_items.each_value do |items|
        ItemContract.validate_items!(items, source: "pasted_response")
      end
      true
    rescue ItemContract::Error
      false
    end

    def update_workflow_test(workflow_test:, params:, guardian:)
      attributes = { updated_by: guardian.user }
      attributes[:name] = params.name if params.name.present?
      attributes[:checks] = params.checks unless params.checks.nil?
      attributes[:pasted_responses] = params.pasted_items unless params.pasted_items.nil?
      workflow_test.update(attributes)
      workflow_test
    end
  end
end
