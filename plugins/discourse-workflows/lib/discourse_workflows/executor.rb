# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    MAX_ITERATIONS = 1000

    def initialize(trigger_node, trigger_data)
      @trigger_node = trigger_node
      @workflow = trigger_node.workflow
      @trigger_data = trigger_data.deep_stringify_keys
      @state =
        ExecutionState.new(
          workflow: @workflow,
          trigger_node: @trigger_node,
          trigger_data: @trigger_data,
        )
    end

    def self.resume(execution, response_items)
      return nil unless execution.waiting?
      trigger_node = execution.workflow.nodes.find_by(id: execution.trigger_node_id)
      return nil unless trigger_node
      new(trigger_node, execution.trigger_data).resume_from(execution, response_items)
    end

    def run
      return nil unless @workflow.enabled?

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
    rescue WaitForHuman => e
      pause_handler.pause!(e)
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
      node_type_class = DiscourseWorkflows::Registry.find_node_type(node.type)
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
            @state.context,
            input_items: input_items,
            node_context: @state.node_context_for(node),
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

    def step_runner
      @step_runner ||= StepRunner.new(@state)
    end

    def pause_handler
      @pause_handler ||= PauseHandler.new(@state)
    end

    def fail_execution(error)
      @state.execution.update!(
        status: :error,
        error: error.message,
        finished_at: Time.current,
        context: @state.context,
      )
      publish_form_status("error") if form_triggered?
      @state.execution
    end

    def finish_execution
      @state.execution.update!(status: :success, context: @state.context, finished_at: Time.current)
      publish_form_status("success") if form_triggered?
      @state.execution
    end

    def form_triggered?
      @trigger_node.type == "trigger:form"
    end

    def publish_form_status(status)
      MessageBus.publish(
        "/discourse-workflows/form-execution/#{@state.execution.id}",
        { status: status },
      )
    end
  end
end
