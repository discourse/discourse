# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowCallContinuation
    class << self
      def begin_child_call!(execution:, node:, request:)
        payload = request.payload.deep_stringify_keys
        call = payload.fetch("call")

        run =
          WorkflowCallRun.create!(
            parent_execution_id: execution.id,
            parent_node_id: node.id,
            parent_resume_token: execution.resume_token,
            target_workflow_id: call.fetch("workflow_id"),
            target_workflow_version_id: call.fetch("workflow_version_id"),
            user_id: payload["user_id"],
            trigger_data: call.fetch("trigger_data"),
          )

        enqueue_run(run)
      end

      def run!(run_id:)
        return unless SiteSetting.discourse_workflows_enabled

        run = WorkflowCallRun.find_by(id: run_id)
        return if run.blank?

        run_workflow_call!(run)
      end

      def child_succeeded!(execution)
        run = transition_run!(execution, status: :success) or return

        resume_parent_success(run)
      end

      def child_failed!(execution)
        message = execution_failed_message(execution)
        run = transition_run!(execution, status: :error, error: message) or return

        finalize_failed!(run, DiscourseWorkflows::NodeError.new(message))
      end

      def workflow_call_stack_for(parent_execution, visited = Set.new)
        return [] unless visited.add?(parent_execution.id)

        parent_run = WorkflowCallRun.find_by(child_execution_id: parent_execution.id)
        stack =
          if parent_run
            workflow_call_stack_for(parent_run.parent_execution, visited)
          else
            []
          end

        stack + [parent_execution.workflow_id.to_s]
      end

      def caller_metadata_for(child_execution)
        run = WorkflowCallRun.find_by(child_execution_id: child_execution.id)
        run && caller_metadata(run)
      end

      private

      def transition_run!(execution, status:, error: nil)
        run = WorkflowCallRun.find_by(child_execution_id: execution.id)
        return if run.blank?

        updated =
          WorkflowCallRun
            .active
            .where(id: run.id)
            .update_all(
              status: WorkflowCallRun.statuses[status],
              error: error,
              updated_at: Time.current,
            )
        return if updated.zero?

        run.reload
      end

      def enqueue_run(run)
        Jobs.enqueue(Jobs::DiscourseWorkflows::RunWorkflowCall, run_id: run.id)
      end

      def run_workflow_call!(run)
        claimed = WorkflowCallRun.claim_pending(run)
        return if claimed.blank?

        workflow = Workflow.find_by(id: claimed.target_workflow_id)
        workflow_version =
          WorkflowVersion.find_by(
            workflow_id: claimed.target_workflow_id,
            version_id: claimed.target_workflow_version_id,
          )
        trigger_node = Nodes::WorkflowCallTrigger::V1.find_in(workflow_version&.nodes)

        if workflow.blank? || workflow_version.blank? || trigger_node.blank?
          return(
            fail_run!(
              claimed,
              I18n.t("discourse_workflows.errors.workflow_call.target_not_callable"),
            )
          )
        end

        executor =
          Executor.new(
            workflow,
            trigger_node["id"],
            claimed.trigger_data,
            Executor::ExecutionOptions.new(
              user: claimed.user,
              workflow_version: workflow_version,
              workflow_call_stack: workflow_call_stack_for(claimed.parent_execution),
              workflow_call_caller: caller_metadata(claimed),
              workflow_call_run_id: claimed.id,
            ),
          )
        execution = executor.run

        claimed.update!(child_execution_id: execution.id, status: :waiting) if execution.waiting?
      rescue => e
        fail_run!(claimed || run, e.message)
      end

      def fail_run!(run, message)
        run.update!(status: :error, error: message)
        finalize_failed!(run, DiscourseWorkflows::NodeError.new(message))
      end

      def finalize_failed!(run, error)
        resume_parent_error(run, error)
      end

      def resume_parent_success(run)
        with_claimed_parent(run) do |claimed|
          DiscourseWorkflows::Executor.resume(claimed, child_output_items(run))
        end
      end

      def resume_parent_error(run, error)
        with_claimed_parent(run) do |claimed|
          DiscourseWorkflows::Executor.resume_with_error(claimed, error)
        end
      end

      def with_claimed_parent(run)
        claimed =
          DiscourseWorkflows::Execution.claim_for_resume(
            run.parent_execution.reload,
            resume_token: run.parent_resume_token,
          )
        yield claimed if claimed.present?
      end

      def child_output_items(run)
        output = run.child_execution.execution_data&.steps_array&.last&.dig("output") || []
        output.map { |item| item.except(Item::PAIRED_ITEM_KEY) }
      end

      def caller_metadata(run)
        parent = run.parent_execution
        node = parent.workflow_node(run.parent_node_id) || {}
        workflow_id = parent.workflow_id
        execution_id = parent.id

        {
          "workflow_id" => workflow_id,
          "workflow_name" => parent.workflow_snapshot_name,
          "execution_id" => execution_id,
          "execution_url" =>
            DiscourseWorkflows::Execution.admin_execution_url(workflow_id, execution_id),
          "node_id" => node["id"] || run.parent_node_id,
          "node_name" => node["name"],
          "node_type" => node["type"],
        }.compact
      end

      def execution_failed_message(execution)
        status = execution&.status || "unknown"
        error = execution&.error.presence
        if error.present?
          I18n.t(
            "discourse_workflows.errors.workflow_call.execution_failed_with_error",
            status: status,
            error: error,
          )
        else
          I18n.t("discourse_workflows.errors.workflow_call.execution_failed", status: status)
        end
      end
    end
  end
end
