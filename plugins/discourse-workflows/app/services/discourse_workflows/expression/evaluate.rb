# frozen_string_literal: true

module DiscourseWorkflows
  class Expression::Evaluate
    include Service::Base

    params do
      attribute :template, :string
      attribute :workflow_id, :integer
      attribute :node_id, :string

      validates :template, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow, optional: true
    model :preview_context, :build_preview_context
    model :segments, :resolve_segments, optional: true

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def build_preview_context(workflow:, params:)
      Workflow::Action::BuildExpressionPreviewContext.call(workflow:, node_id: params.node_id)
    end

    def resolve_segments(params:, preview_context:, guardian:)
      ExpressionResolver.resolve_segments(
        params.template,
        context: preview_context,
        user: guardian.user,
      )
    end
  end
end
