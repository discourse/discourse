# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    include FormExecutionChannel

    MAX_ITERATIONS = 1000

    class WaitRequested < StandardError
      attr_reader :wait_request

      def initialize(wait_request)
        @wait_request = wait_request
        super("Wait requested: #{wait_request.type}")
      end
    end

    delegate :execution, to: :@store

    def initialize(workflow, trigger_node_id, trigger_data, options = ExecutionOptions.new)
      @workflow = workflow
      @trigger_node_id = trigger_node_id.to_s
      @trigger_data = trigger_data.deep_stringify_keys
      @options = options
      @context =
        ExecutionContext.new(workflow: @workflow, trigger_data: @trigger_data, user: @options.user)
      @store =
        ExecutionStore.new(
          trigger_node_id: @trigger_node_id,
          execution_context: @context,
          execution_mode: @options.execution_mode,
          options: @options,
        )
      @steps = []
      @queue = []
      @sandbox = nil
      @waiting_node = nil
      @waiting_step = nil
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
      return @store.create_execution_with_status(:skipped) unless @workflow.enabled?
      return @store.create_execution_with_status(:rate_limited) unless rate_limiter.within_limits?

      start_execution!
      execute_flow do
        trigger_node = @snapshot.find_node(@trigger_node_id)
        raise "Trigger node #{@trigger_node_id} not found in workflow snapshot" if trigger_node.nil?

        trigger_items = [Item.new(@trigger_data).to_h]
        ItemContract.validate_items!(trigger_items, source: "trigger:#{trigger_node.type}")
        record_step(trigger_node, [], output: trigger_items, status: Step::SUCCESS)
        @context.store_node_output(trigger_node, trigger_items)
        enqueue_downstream(trigger_node, "main", trigger_items)
      end
    end

    def resume_from(execution, response_items)
      resume_execution!(execution)

      waiting_node_id = execution.waiting_node_id
      waiting_node = @snapshot.find_node(waiting_node_id)
      raise "Waiting node #{waiting_node_id} not found in workflow snapshot" if waiting_node.nil?

      update_waiting_step(waiting_node, response_items)
      @context.store_node_output(waiting_node, response_items)
      clear_waiting!

      ItemContract.validate_items!(response_items, source: "resume:#{waiting_node.type}")
      execute_flow { enqueue_downstream(waiting_node, "main", response_items) }
    end

    private

    # --- Main loop ---

    def execute_flow
      yield
      process_queue
      @store.finish!(steps: @steps)
    rescue WaitRequested => e
      begin_wait!(e.wait_request)
    rescue => e
      @store.fail!(error: e, steps: @steps)
    ensure
      @sandbox&.dispose
    end

    def process_queue
      iterations = 0

      while @queue.any?
        iterations += 1
        raise "Max iterations (#{MAX_ITERATIONS}) exceeded" if iterations > MAX_ITERATIONS

        node, input_items = @queue.shift
        execute_node(node, input_items)
      end
    end

    # --- Node execution ---

    def execute_node(node, input_items)
      node_type_class =
        DiscourseWorkflows::Registry.find_node_type(node.type, version: node.type_version)
      return handle_unknown_node(node, input_items) unless node_type_class

      step = record_step(node, input_items)
      resolver = build_resolver(node, input_items)

      begin
        exec_ctx = build_node_execution_context(node, input_items, node_type_class, resolver)
        result = node_type_class.new(configuration: node.configuration).execute(exec_ctx)

        if result.is_a?(WaitForResume)
          step.mark_waiting!
          @waiting_node = node
          @waiting_step = step
          raise WaitRequested, result
        end

        step_log = collect_step_log(exec_ctx)
        attach_step_log(step, step_log)
        if step_log&.errors?
          step.fail!(step_log.error_summary)
          raise StandardError, step.error
        end

        normalized = normalize_result(result, node, node_type_class.ports)
        all_items = normalized.all_items(ports: node_type_class.ports)
        primary_empty = normalized.primary_items(ports: node_type_class.ports).empty?

        if node_type_class.branching? && primary_empty
          step.filter!(output: all_items)
        else
          step.succeed!(output: all_items)
        end

        @context.store_node_output(node, all_items)
        route_downstream(node, node_type_class.ports, normalized)
      rescue WaitRequested
        raise
      rescue => e
        step.fail!(e.message) unless step.error?
        attach_step_log(step, collect_step_log(exec_ctx)) unless step.metadata&.key?("logs")
        raise
      ensure
        resolver&.dispose
      end
    end

    def collect_step_log(exec_ctx)
      return unless exec_ctx

      exec_ctx.collect_errors!
      log = exec_ctx.log || StepLog.new
      errors = exec_ctx.expression_errors || []
      errors.each { |err| log.error("#{err[:expression]}: #{err[:error]}") } if errors.present?
      log
    end

    def attach_step_log(step, step_log)
      return if step_log.nil? || step_log.empty?

      step.add_metadata("logs", step_log.as_json)
    end

    def handle_unknown_node(node, input_items)
      Rails.logger.warn(
        "discourse-workflows: unknown node type '#{node.type}' (version: #{node.type_version}) " \
          "in workflow #{@context.workflow.id}, skipping node '#{node.name}'",
      )
      record_step(node, input_items, status: Step::ERROR, error: "Unknown node type '#{node.type}'")
    end

    def build_node_execution_context(node, input_items, node_type_class, resolver)
      NodeExecutionContext.new(
        input_items: input_items,
        configuration: node.configuration,
        property_schema: node_type_class.property_schema,
        node_context: @context.node_context_for(node),
        user: @options.user,
        run_as_user: run_as_user,
        resolver: resolver,
        vars: preloaded_vars,
      )
    end

    def normalize_result(result, node, ports)
      normalized =
        if result.is_a?(NodeResult)
          result
        else
          ItemContract.validate_output_arrays!(result, source: node.type)
          NodeResult.from_output_arrays(result, ports: ports)
        end

      ItemContract.validate_node_result!(normalized, source: node.type, ports: ports)
      normalized
    end

    # --- Routing ---

    def route_downstream(node, ports, result)
      result
        .output_arrays(ports: ports)
        .each_with_index do |items, index|
          next if items.empty?
          enqueue_downstream(node, ports.dig(index, :key) || "main", items)
        end
    end

    def enqueue_downstream(node, output_name, items)
      @snapshot
        .connections_from(node)
        .each do |conn|
          next if conn.source_output.present? && conn.source_output != output_name
          next if conn.source_output.blank? && output_name != "main"

          target = @snapshot.target_node(conn)
          @queue << [target, items] if target
        end
    end

    # --- Steps ---

    def record_step(node, input_items, output: [], status: Step::RUNNING, error: nil)
      step =
        Step.build(
          node: node,
          position: @steps.size,
          input: input_items,
          output: output,
          status: status,
          error: error,
        )
      @steps << step
      step
    end

    def update_waiting_step(waiting_node, response_items)
      step = @steps.find { |s| s.node_id == waiting_node.id.to_s && s.status == Step::WAITING }
      step&.apply_updates!(
        "status" => Step::SUCCESS,
        "output" => response_items,
        "finished_at" => Time.current.iso8601,
      )
    end

    # --- Wait handling ---

    def begin_wait!(wait_request)
      handler =
        WaitHandlers.for(wait_request.type).new(
          persistence: @store,
          context: @context,
          node: @waiting_node,
          step: @waiting_step,
          steps: @steps,
        )
      handler.begin_wait!(wait_request)
    rescue => e
      @store.fail!(error: e, steps: @steps)
    end

    # --- Lifecycle ---

    def start_execution!
      @store.start!
      @snapshot = WorkflowSnapshot.new(@store.workflow_snapshot_data)
      @steps = []
      @queue = []
    end

    def resume_execution!(execution)
      @store.resume!(execution)
      @snapshot = WorkflowSnapshot.new(@store.workflow_snapshot_data)
      @steps = restore_steps_from(execution)
      @queue = []
    end

    def clear_waiting!
      @store.clear_waiting_execution!
      @waiting_node = nil
      @waiting_step = nil
    end

    def restore_steps_from(execution)
      entries = execution.execution_data&.entries || {}
      entries.values.flatten.map { |h| Step.from_h(h) }
    end

    # --- Helpers ---

    def build_resolver(node, input_items)
      base = @context.resolver_context
      first_json = input_items.first&.dig("json")
      context = first_json ? base.merge("$json" => first_json) : base
      ExpressionResolver.new(context, user: @options.user, sandbox: shared_sandbox)
    end

    def shared_sandbox
      @sandbox ||=
        DiscourseWorkflows::JsSandbox.new(
          @context.resolver_context,
          user: @options.user,
          vars: preloaded_vars,
        )
    end

    def preloaded_vars
      @preloaded_vars ||= DiscourseWorkflows::Variable.pluck(:key, :value).to_h
    end

    def rate_limiter
      @rate_limiter ||= ExecutionRateLimiter.new(@workflow)
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
