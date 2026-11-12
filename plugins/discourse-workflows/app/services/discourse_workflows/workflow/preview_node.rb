# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::PreviewNode
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :node_id, :string
      attribute :parameters

      validates :workflow_id, presence: true
      validates :node_id, presence: true
      validate :parameters_must_be_a_hash

      private

      def parameters_must_be_a_hash
        return if parameters.nil? || parameters.is_a?(Hash)
        errors.add(:parameters, :invalid)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :workflow_snapshot
    model :node
    model :node_type_class
    policy :node_type_previewable
    model :preview_context, :build_preview_context
    model :output, :run_node

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_snapshot(workflow:)
      DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow, published: false)
    end

    def fetch_node(workflow_snapshot:, params:)
      workflow_snapshot.find_node(params.node_id)
    end

    def fetch_node_type_class(node:)
      DiscourseWorkflows::Registry.find_node_type(node.type, version: node.type_version)
    end

    def node_type_previewable(node_type_class:)
      node_type_class.previewable? && node_type_class.available?
    end

    def build_preview_context(workflow:, params:)
      Workflow::Action::BuildExpressionPreviewContext.call(workflow:, node_id: params.node_id)
    end

    def run_node(workflow_snapshot:, node:, node_type_class:, preview_context:, params:, guardian:)
      Workflow::Action::RunNodePreview.call(
        workflow_snapshot:,
        node:,
        node_type_class:,
        preview_context:,
        parameters: params.parameters,
        user: guardian.user,
      )
    end
  end
end
