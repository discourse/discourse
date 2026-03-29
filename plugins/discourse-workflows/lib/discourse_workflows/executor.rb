# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    MAX_ITERATIONS = 1000
    MAX_ERROR_DEPTH = 3

    delegate :execution, to: :@state

    def initialize(trigger_node, trigger_data, user: nil, execution_mode: :normal, error_depth: 0)
      @trigger_node = trigger_node
      @workflow = trigger_node.workflow
      @trigger_data = trigger_data.deep_stringify_keys
      @user = user
      @execution_mode = execution_mode
      @error_depth = error_depth
      @state =
        ExecutionState.new(
          workflow: @workflow,
          trigger_node: @trigger_node,
          trigger_data: @trigger_data,
          user: @user,
          execution_mode: @execution_mode,
        )
    end

    def self.resume(execution, response_items, user: nil)
      return nil unless execution.waiting?
      trigger_node = execution.workflow.nodes.find_by(id: execution.trigger_node_id)
      return nil unless trigger_node
      new(
        trigger_node,
        execution.trigger_data,
        user: user,
        execution_mode: execution.execution_mode.to_sym,
      ).resume_from(execution, response_items)
    end

    def run
      return nil unless @workflow.enabled?
      unless rate_limiter.performed!(raise_error: false) &&
               per_workflow_rate_limiter.performed!(raise_error: false)
        now = Time.current
        return(
          DiscourseWorkflows::Execution.create!(
            workflow: @workflow,
            trigger_node_id: @trigger_node.id,
            status: :rate_limited,
            trigger_data: @trigger_data,
            workflow_data: WorkflowSnapshot.snapshot(@workflow),
            execution_mode: @execution_mode,
            started_at: now,
            finished_at: now,
          )
        )
      end

      @state.start!
      @snapshot = WorkflowSnapshot.new(@state.execution.workflow_data)

      execute_flow do
        trigger_node = @snapshot.find_node(@trigger_node.id)
        raise "Trigger node #{@trigger_node.id} not found in workflow snapshot" if trigger_node.nil?

        trigger_items = [{ "json" => @trigger_data }]
        @state.store_context(trigger_node.name, trigger_items) if trigger_node.name.present?
        record_trigger_step(trigger_node, trigger_items)
        enqueue_downstream(trigger_node, "main", trigger_items)
      end
    end

    def resume_from(execution, response_items)
      @state.resume!(execution)
      @snapshot = WorkflowSnapshot.new(execution.workflow_data)

      waiting_node_id = execution.waiting_node_id
      waiting_node = @snapshot.find_node(waiting_node_id)
      raise "Waiting node #{waiting_node_id} not found in workflow snapshot" if waiting_node.nil?

      waiting_step = execution.steps.find_by(node_id: waiting_node_id, status: :waiting)

      @state.store_context(waiting_node.name, response_items)
      waiting_step&.update!(status: :success, output: response_items, finished_at: Time.current)

      @state.clear_waiting_execution!

      execute_flow { enqueue_downstream(waiting_node, "main", response_items) }
    end

    private

    def execute_flow
      yield
      process_queue
      finish_execution
    rescue WaitForResume => e
      begin
        pause_handler.pause!(e)
      rescue => pause_error
        fail_execution(pause_error)
      end
    rescue => e
      fail_execution(e)
    end

    def process_queue
      iterations = 0
      while @state.queued?
        iterations += 1
        raise "Max iterations (#{MAX_ITERATIONS}) exceeded" if iterations > MAX_ITERATIONS

        node, input_items = @state.shift_queue
        execute_node(node, input_items)
      end
    end

    def execute_node(node, input_items)
      node_type_class =
        DiscourseWorkflows::Registry.find_node_type(node.type, version: node.type_version)
      return if node_type_class.nil?

      if node.condition?
        execute_condition(node, node_type_class, input_items)
      else
        execute_action_or_core(node, input_items, node_type_class)
      end
    end

    def execute_condition(node, node_type_class, input_items)
      result =
        step_runner.run(node, input_items, node_type_class) do |instance|
          instance.evaluate(input_items: input_items, context: @state.resolver_context)
        end

      if node_type_class.branching?
        route_outputs(node, result) { |items| @state.store_context(node.name, items) }
      else
        true_items = result["true"] || []
        if true_items.any?
          @state.store_context(node.name, true_items)
          enqueue_downstream(node, "main", true_items)
        end
      end
    end

    def execute_action_or_core(node, input_items, node_type_class)
      result =
        step_runner.run(node, input_items, node_type_class) do |instance|
          instance.execute(
            @state.resolver_context,
            input_items: input_items,
            node_context: @state.node_context_for(node),
            user: @user,
            run_as_user: run_as_user,
          )
        end

      @state.store_context(node.name, result)

      if node_type_class.branching?
        route_outputs(node, result)
      else
        enqueue_downstream(node, "main", result)
      end
    end

    def enqueue_downstream(node, output_name, items)
      @snapshot
        .connections_from(node)
        .each do |connection|
          next if connection.source_output.present? && connection.source_output != output_name
          next if connection.source_output.blank? && output_name != "main"
          target = @snapshot.target_node(connection)
          @state.enqueue(target, items) if target
        end
    end

    def record_trigger_step(node, items)
      now = Time.current
      DiscourseWorkflows::ExecutionStep.create!(
        execution: @state.execution,
        node_id: node.id,
        node_name: node.name,
        node_type: node.type,
        position: @state.next_step_position,
        status: :success,
        input: [],
        output: items,
        started_at: now,
        finished_at: now,
      )
    end

    def route_outputs(node, outputs)
      outputs.each do |output_name, items|
        next if items.empty?

        yield items if block_given?
        enqueue_downstream(node, output_name, items)
      end
    end

    def rate_limiter
      RateLimiter.new(
        nil,
        "discourse_workflows_executions",
        SiteSetting.discourse_workflows_max_executions_per_minute,
        60,
        global: true,
      )
    end

    def per_workflow_rate_limiter
      RateLimiter.new(
        nil,
        "discourse_workflows_workflow_#{@workflow.id}",
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow,
        1.minute,
      )
    end

    def run_as_user
      @run_as_user ||=
        begin
          username = @workflow.run_as_username
          if username.blank? || username == "system"
            Discourse.system_user
          else
            User.find_by(username: username) || Discourse.system_user
          end
        end
    end

    def step_runner
      @step_runner ||= StepRunner.new(@state)
    end

    def pause_handler
      @pause_handler ||= PauseHandler.new(@state)
    end

    def fail_execution(error)
      @state.execution.update!(
        status: :error,
        error: error.message.to_s.truncate(1000),
        finished_at: Time.current,
        context: @state.context,
      )
      publish_form_status("error") if form_triggered?
      trigger_error_workflow(error) if @execution_mode == :normal
      @state.execution
    end

    def finish_execution
      @state.execution.update!(status: :success, context: @state.context, finished_at: Time.current)
      publish_form_completion if form_triggered?
      @state.execution
    end

    def form_triggered?
      @trigger_node.type == "trigger:form"
    end

    def trigger_error_workflow(error)
      return if @error_depth >= MAX_ERROR_DEPTH

      error_workflow = @workflow.error_workflow
      return unless error_workflow&.enabled?
      return if error_workflow.id == @workflow.id

      error_trigger_node = error_workflow.nodes.find_by(type: "trigger:error")
      return unless error_trigger_node

      last_failed_step = @state.execution.steps.where(status: :error).last

      error_data = {
        execution_id: @state.execution.id,
        workflow_id: @workflow.id,
        workflow_name: @workflow.name,
        error_message: error.message.to_s.truncate(1000),
        failed_node_name: last_failed_step&.node_name,
      }

      self
        .class
        .new(
          error_trigger_node,
          error_data,
          user: @user,
          execution_mode: :error_mode,
          error_depth: @error_depth + 1,
        )
        .run
    end

    def publish_form_completion
      completion = @state.context["__form_completion"]
      message = { status: "success" }
      message[:form_completion] = completion if completion.present?
      MessageBus.publish(form_channel(@state.execution.id), message)
    end

    def publish_form_status(status)
      MessageBus.publish(form_channel(@state.execution.id), { status: status })
    end

    def form_channel(execution_id)
      self.class.form_channel(execution_id)
    end

    def self.form_channel(execution_id)
      token = HmacSigner.sign("form_execution:#{execution_id}")
      "/discourse-workflows/form-execution/#{execution_id}-#{token}"
    end
  end
end
