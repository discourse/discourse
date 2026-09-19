# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionSerializer < ApplicationSerializer
    attributes :id,
               :workflow_id,
               :workflow_name,
               :status,
               :trigger_data,
               :error,
               :run_time_ms,
               :started_at,
               :finished_at,
               :created_at,
               :workflow_call_caller

    attribute :steps

    def workflow_name
      object.workflow_snapshot_name
    end

    def workflow_call_caller
      return @workflow_call_caller if defined?(@workflow_call_caller)

      @workflow_call_caller =
        DiscourseWorkflows::WorkflowCallContinuation.caller_metadata_for(object)
    end

    def include_workflow_call_caller?
      workflow_call_caller.present?
    end

    STEP_FIELDS = %w[
      node_id
      node_name
      node_type
      position
      status
      input
      output
      error
      metadata
      started_at
      finished_at
    ].freeze

    def steps
      return [] unless object.execution_data

      workflow_call_runs = workflow_call_runs_by_parent_node_id
      object.execution_data.steps_array.map do |step|
        serialized_step = step.slice(*STEP_FIELDS).symbolize_keys
        metadata = serialized_step[:metadata]
        serialized_step[:metadata] = metadata.except("workflow_call") if metadata

        if (workflow_call_run = workflow_call_runs[step["node_id"]])
          serialized_step[:workflow_call_run] = workflow_call_run_data(workflow_call_run)
        end

        serialized_step
      end
    end

    private

    def workflow_call_runs_by_parent_node_id
      # Workflow executions currently record one step entry per node, so the
      # parent node id is enough to attach the child run. If a node can run
      # more than once in one execution, WorkflowCallRun will need a step/run
      # correlation id instead.
      @workflow_call_runs_by_parent_node_id ||=
        object
          .initiated_workflow_call_runs
          .includes(:child_execution, :target_workflow)
          .order(:id)
          .index_by(&:parent_node_id)
    end

    def workflow_call_run_data(workflow_call_run)
      child_execution = workflow_call_run.child_execution

      {
        "run_id" => workflow_call_run.id,
        "workflow_id" => workflow_call_run.target_workflow_id,
        "workflow_name" => workflow_call_run.target_workflow&.name,
        "execution_id" => workflow_call_run.child_execution_id,
        "execution_url" => workflow_call_execution_url(workflow_call_run),
        "status" => child_execution&.status || workflow_call_run.status,
        "error" => workflow_call_run.error,
      }.compact
    end

    def workflow_call_execution_url(workflow_call_run)
      return if workflow_call_run.child_execution_id.blank?

      DiscourseWorkflows::Execution.admin_execution_url(
        workflow_call_run.target_workflow_id,
        workflow_call_run.child_execution_id,
      )
    end
  end
end
