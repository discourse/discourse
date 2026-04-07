# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    include FormPublishing

    MAX_ITERATIONS = 1000

    delegate :execution, to: :@state

    def initialize(workflow, trigger_node_id, trigger_data, options = ExecutionOptions.new)
      @workflow = workflow
      @trigger_node_id = trigger_node_id.to_s
      @trigger_data = trigger_data.deep_stringify_keys
      @options = options
      @state =
        ExecutionState.new(
          workflow: @workflow,
          trigger_node_id: @trigger_node_id,
          trigger_data: @trigger_data,
          options: @options,
        )
      @completion = CompletionHandler.new(state: @state, options: @options)
    end

    def self.resume(execution, response_items, user: nil)
      unless execution.waiting?
        raise ArgumentError,
              "Cannot resume execution #{execution.id} with status '#{execution.status}'"
      end

      workflow = execution.workflow
      trigger_node_id = execution.trigger_node_id

      unless workflow.find_node(trigger_node_id)
        raise "Trigger node #{trigger_node_id} not found in workflow #{workflow.id}"
      end

      options = ExecutionOptions.new(user: user, execution_mode: execution.execution_mode.to_sym)
      new(workflow, trigger_node_id, execution.trigger_data, options).resume_from(
        execution,
        response_items,
      )
    end

    def run
      return @completion.create_terminal(:skipped) unless @workflow.enabled?
      return @completion.create_terminal(:rate_limited) unless rate_limiter.within_limits?

      @state.start!
      build_pipeline

      execute_flow do
        trigger_node = @snapshot.find_node(@trigger_node_id)
        raise "Trigger node #{@trigger_node_id} not found in workflow snapshot" if trigger_node.nil?

        trigger_items = [Item.new(@trigger_data).to_h]
        ItemContract.validate_items!(trigger_items, source: "trigger:#{trigger_node.type}")
        @state.store_context(trigger_node.name, trigger_items) if trigger_node.name.present?
        @router.record_trigger_step(trigger_node, trigger_items)
        @router.enqueue_downstream(trigger_node, "main", trigger_items)
      end
    end

    def resume_from(execution, response_items)
      @state.resume!(execution)
      build_pipeline

      waiting_node_id = execution.waiting_node_id
      waiting_node = @snapshot.find_node(waiting_node_id)
      raise "Waiting node #{waiting_node_id} not found in workflow snapshot" if waiting_node.nil?

      @state.update_step_in_run_data!(
        node_id: waiting_node_id,
        from_status: Step::WAITING,
        updates: {
          "status" => Step::SUCCESS,
          "output" => response_items,
          "finished_at" => Time.current.iso8601,
        },
      )

      @state.store_context(waiting_node.name, response_items)
      @state.clear_waiting_execution!

      ItemContract.validate_items!(response_items, source: "resume:#{waiting_node.type}")
      execute_flow { @router.enqueue_downstream(waiting_node, "main", response_items) }
    end

    private

    def build_pipeline
      @snapshot = WorkflowSnapshot.new(@state.workflow_snapshot_data)
      @completion.snapshot = @snapshot
      step_runner = StepRunner.new(@state)
      @router =
        NodeRouter.new(
          state: @state,
          step_runner: step_runner,
          snapshot: @snapshot,
          user: @options.user,
          run_as_user_proc: method(:run_as_user),
        )
    end

    def execute_flow
      yield
      process_queue
      @completion.finish!
    rescue WaitForResume => e
      @completion.wait!(e)
    rescue => e
      @completion.fail!(e)
    ensure
      @state.dispose_shared_sandbox
    end

    def process_queue
      iterations = 0
      while @state.queued?
        iterations += 1
        raise "Max iterations (#{MAX_ITERATIONS}) exceeded" if iterations > MAX_ITERATIONS

        node, input_items = @state.shift_queue
        commands = @router.execute_node(node, input_items)
        apply_commands!(commands)
      end
    end

    def apply_commands!(commands)
      commands.each do |cmd|
        case cmd
        when RoutingCommand::StoreContext
          @state.store_context(cmd.name, cmd.items)
        when RoutingCommand::Enqueue
          @state.enqueue(cmd.node, cmd.items)
        when RoutingCommand::RecordStep
          @state.record_step(cmd.node_name, cmd.step)
        when RoutingCommand::Pause
          @state.mark_wait(node: cmd.node, step: cmd.step)
          raise cmd.error
        end
      end
    end

    def rate_limiter
      @rate_limiter ||= ExecutorRateLimiter.new(@workflow)
    end

    def run_as_user
      @run_as_user ||=
        if @workflow.run_as_username.blank? || @workflow.run_as_username == "system"
          Discourse.system_user
        else
          User.find_by(username: @workflow.run_as_username) || Discourse.system_user
        end
    end
  end
end
