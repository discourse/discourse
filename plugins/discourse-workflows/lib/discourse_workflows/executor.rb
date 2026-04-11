# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    include FormPublishing

    MAX_ITERATIONS = 1000

    delegate :execution, to: :@persistence

    def initialize(workflow, trigger_node_id, trigger_data, options = ExecutionOptions.new)
      @workflow = workflow
      @trigger_node_id = trigger_node_id.to_s
      @trigger_data = trigger_data.deep_stringify_keys
      @options = options
      @context =
        ExecutionContext.new(workflow: @workflow, trigger_data: @trigger_data, user: @options.user)
      @journal = StepsJournal.new
      @runtime = ExecutionRuntime.new(context: @context, user: @options.user)
      @persistence =
        ExecutionPersistence.new(
          trigger_node_id: @trigger_node_id,
          execution_context: @context,
          steps_journal: @journal,
          execution_mode: @options.execution_mode,
        )
      @completion =
        CompletionHandler.new(
          persistence: @persistence,
          context: @context,
          journal: @journal,
          runtime: @runtime,
          options: @options,
        )
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

      start_execution!
      build_pipeline

      execute_flow do
        trigger_node = @snapshot.find_node(@trigger_node_id)
        raise "Trigger node #{@trigger_node_id} not found in workflow snapshot" if trigger_node.nil?

        trigger_items = [Item.new(@trigger_data).to_h]
        ItemContract.validate_items!(trigger_items, source: "trigger:#{trigger_node.type}")
        @context.store_context(trigger_node.name, trigger_items) if trigger_node.name.present?
        @router.record_trigger_step(trigger_node, trigger_items)
        @router.enqueue_downstream(trigger_node, "main", trigger_items)
      end
    end

    def resume_from(execution, response_items)
      resume_execution!(execution)
      build_pipeline

      waiting_node_id = execution.waiting_node_id
      waiting_node = @snapshot.find_node(waiting_node_id)
      raise "Waiting node #{waiting_node_id} not found in workflow snapshot" if waiting_node.nil?

      @journal.update_step!(
        node_id: waiting_node_id,
        from_status: Step::WAITING,
        updates: {
          "status" => Step::SUCCESS,
          "output" => response_items,
          "finished_at" => Time.current.iso8601,
        },
      )

      @context.store_context(waiting_node.name, response_items)
      clear_waiting_execution!

      ItemContract.validate_items!(response_items, source: "resume:#{waiting_node.type}")
      execute_flow { @router.enqueue_downstream(waiting_node, "main", response_items) }
    end

    private

    def build_pipeline
      @snapshot = WorkflowSnapshot.new(@persistence.workflow_snapshot_data)
      @completion.snapshot = @snapshot
      step_runner =
        StepRunner.new(context: @context, journal: @journal, runtime: @runtime, user: @options.user)
      @router =
        NodeRouter.new(
          context: @context,
          journal: @journal,
          runtime: @runtime,
          step_runner: step_runner,
          snapshot: @snapshot,
          user: @options.user,
          run_as_user_proc: method(:run_as_user),
        )
    end

    def execute_flow
      yield
      outcome = process_queue

      if outcome.wait?
        @completion.wait!(outcome.wait)
      else
        @completion.finish!
      end
    rescue => e
      @completion.fail!(e)
    ensure
      @runtime.dispose_shared_sandbox
    end

    def process_queue
      iterations = 0
      while @runtime.queued?
        iterations += 1
        raise "Max iterations (#{MAX_ITERATIONS}) exceeded" if iterations > MAX_ITERATIONS

        node, input_items = @runtime.shift_queue
        commands = @router.execute_node(node, input_items)
        outcome = apply_commands!(commands)
        return outcome if outcome.wait?
      end

      ExecutionOutcome.complete
    end

    def apply_commands!(commands)
      commands.each do |cmd|
        case cmd
        when RoutingCommand::StoreContext
          @context.store_context(cmd.name, cmd.items)
        when RoutingCommand::Enqueue
          @runtime.enqueue(cmd.node, cmd.items)
        when RoutingCommand::RecordStep
          @journal.record_step(cmd.node_name, cmd.step)
        when RoutingCommand::Pause
          @runtime.mark_wait(node: cmd.node, step: cmd.step)
          return ExecutionOutcome.wait(wait: cmd.wait)
        end
      end

      ExecutionOutcome.complete
    end

    def start_execution!
      @persistence.start!
      @runtime.reset!
    end

    def resume_execution!(execution)
      @persistence.resume!(execution)
      @runtime.reset!
    end

    def clear_waiting_execution!
      @persistence.clear_waiting_execution!
      @runtime.clear_wait
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
