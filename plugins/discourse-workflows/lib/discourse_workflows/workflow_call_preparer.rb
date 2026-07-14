# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowCallPreparer
    include DiscourseWorkflows::NodeErrorHandling

    MAX_WORKFLOW_CALL_DEPTH = 10
    MAX_TRIGGER_DATA_BYTES = 1.megabyte

    PreparedCall = Data.define(:workflow, :workflow_version, :trigger_data)

    def initialize(exec_ctx:, workflow_id:, trigger_data:)
      @exec_ctx = exec_ctx
      @workflow_id = workflow_id.to_s
      @trigger_data = trigger_data
    end

    def prepare
      validate_workflow_id!
      @exec_ctx.ensure_workflow_call_access!(@workflow_id)
      ensure_stack_allows_call!
      ensure_trigger_data_within_budget!

      workflow = target_workflow
      workflow_version = workflow&.active_version
      ensure_callable_workflow!(workflow)

      PreparedCall.new(
        workflow: workflow,
        workflow_version: workflow_version,
        trigger_data: @trigger_data,
      )
    end

    private

    def validate_workflow_id!
      if @workflow_id.blank?
        raise_node_error!(I18n.t("discourse_workflows.errors.workflow_call.workflow_required"))
      end
    end

    def ensure_trigger_data_within_budget!
      return if @trigger_data.to_json.bytesize <= MAX_TRIGGER_DATA_BYTES

      raise_node_error!(
        I18n.t(
          "discourse_workflows.errors.workflow_call.payload_too_large",
          max: MAX_TRIGGER_DATA_BYTES,
        ),
      )
    end

    def ensure_stack_allows_call!
      stack = @exec_ctx.workflow_call_stack.map(&:to_s)

      if stack.include?(@workflow_id)
        raise_node_error!(I18n.t("discourse_workflows.errors.workflow_call.recursive_call"))
      end

      if stack.length >= MAX_WORKFLOW_CALL_DEPTH
        raise_node_error!(
          I18n.t(
            "discourse_workflows.errors.workflow_call.max_depth_exceeded",
            max: MAX_WORKFLOW_CALL_DEPTH,
          ),
        )
      end
    end

    def target_workflow
      @target_workflow ||= Workflow.includes(:active_version).find_by(id: @workflow_id)
    end

    def ensure_callable_workflow!(workflow)
      if workflow.nil?
        raise_node_error!(I18n.t("discourse_workflows.errors.workflow_call.target_not_found"))
      end

      unless workflow.callable_as_subworkflow?
        raise_node_error!(I18n.t("discourse_workflows.errors.workflow_call.target_not_callable"))
      end
    end
  end
end
