# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    MAX_ITERATIONS = 1000
    MAX_WAIT_DURATION_SECONDS = 30.days.to_i
    MAX_NODE_OUTPUT_BYTES = 50.megabytes

    class ExecutionPaused < StandardError
      attr_reader :wait_request

      delegate :waiting_until, to: :@wait_request

      def initialize(wait_request)
        @wait_request = wait_request
        super("Execution paused")
      end
    end

    delegate :execution, to: :@store

    def initialize(workflow, trigger_node_id, trigger_data, options = ExecutionOptions.new)
      @workflow = workflow
      @trigger_node_id = trigger_node_id.to_s
      @trigger_data =
        if trigger_data.is_a?(Array)
          trigger_data.map(&:deep_stringify_keys)
        else
          trigger_data.deep_stringify_keys
        end
      @options = options
      workflow_version = @options.workflow_version
      workflow_nodes =
        if @options.workflow_snapshot
          @options.workflow_snapshot.to_h["nodes"]
        elsif workflow_version
          workflow_version.nodes
        elsif @options.draft_execution
          @workflow.nodes
        else
          @workflow.published_nodes
        end
      @context =
        ExecutionContext.new(
          workflow: @workflow,
          trigger_data: @trigger_data,
          user: @options.user,
          workflow_nodes: workflow_nodes,
          workflow_name: workflow_version&.name,
          workflow_call_caller: @options.workflow_call_caller,
        )
      @store =
        ExecutionStore.new(
          trigger_node_id: @trigger_node_id,
          execution_context: @context,
          execution_mode: @options.execution_mode,
          options: @options,
        )
      @steps = []
      @queue = []
      @queue_index = 0
      @waiting_inputs = {}
      @waiting_input_sources = {}
      @waiting_input_targets = {}
      @input_wait_requirements = {}
      @sandbox = nil
      @waiting_node = nil
      @waiting_step = nil
      @pin_data_by_node_name = resolved_pin_data
      @workflow_call_stack = normalized_workflow_call_stack
    end

    def self.resume(execution, response_items, user: nil, webhook_context: nil)
      build_resume_executor(execution, user: user, webhook_context: webhook_context).resume_from(
        execution,
        response_items,
      )
    end

    def self.resume_with_error(execution, error, user: nil)
      build_resume_executor(execution, user: user).resume_from_error(execution, error)
    end

    def self.build_resume_executor(execution, user:, webhook_context: nil)
      workflow_call_caller = WorkflowCallContinuation.caller_metadata_for(execution)
      options =
        ExecutionOptions.new(
          user: user,
          execution_mode: execution.execution_mode.to_sym,
          workflow_snapshot: build_resume_snapshot!(execution),
          webhook_context: webhook_context,
          workflow_call_stack: WorkflowCallContinuation.workflow_call_stack_for(execution),
          workflow_call_child: workflow_call_caller.present?,
          workflow_call_caller: workflow_call_caller,
        )
      new(execution.workflow, execution.trigger_node_id, execution.trigger_data, options)
    end
    private_class_method :build_resume_executor

    def self.build_resume_snapshot!(execution)
      unless execution.running?
        raise ArgumentError,
              "Cannot resume execution #{execution.id} with status '#{execution.status}' " \
                "(callers must claim via Execution.claim_for_resume first)"
      end

      snapshot =
        if execution.execution_data&.workflow_data.present?
          WorkflowSnapshot.new(execution.execution_data.workflow_data)
        else
          WorkflowSnapshot.from_workflow(execution.workflow, published: true)
        end

      unless snapshot.find_node(execution.trigger_node_id)
        raise "Trigger node #{execution.trigger_node_id} not found in workflow #{execution.workflow.id}"
      end

      snapshot
    end
    private_class_method :build_resume_snapshot!

    def run
      unless @workflow.published? || @options.draft_execution || @options.workflow_version ||
               @options.workflow_snapshot
        return @store.create_execution_with_status(:skipped)
      end
      return @store.create_rate_limited_execution unless rate_limiter.within_limits?

      execute_flow(:start_execution!) do
        next prepare_step_flow! if step_mode?

        trigger_node = @snapshot.find_node(@trigger_node_id)
        raise "Trigger node #{@trigger_node_id} not found in workflow snapshot" if trigger_node.nil?

        seed_trigger_node!(trigger_node)
      end
    end

    def resume_from(execution, response_items)
      execute_flow(:resume_execution!, execution) do
        waiting_node_id = execution.waiting_node_id
        waiting_node = @snapshot.find_node(waiting_node_id)
        raise "Waiting node #{waiting_node_id} not found in workflow snapshot" if waiting_node.nil?

        update_waiting_step(waiting_node, response_items)
        @context.store_node_output(waiting_node, response_items)
        @context.store_node_run(
          waiting_node,
          inputs: [],
          outputs: [response_items],
          input_sources: @context.consume_waiting_input_sources,
        )
        clear_waiting!

        ItemContract.validate_items!(response_items, source: "resume:#{waiting_node.type}")
        enqueue_downstream(waiting_node, 0, response_items)
      end
    end

    def resume_from_error(execution, error)
      execute_flow(:resume_execution!, execution) do
        waiting_node_id = execution.waiting_node_id
        waiting_node = @snapshot.find_node(waiting_node_id)
        raise "Waiting node #{waiting_node_id} not found in workflow snapshot" if waiting_node.nil?

        step = @steps.find { |entry| entry.node_id == waiting_node.id.to_s && entry.waiting? }
        input_items = execution.waiting_step_input_items
        input_groups = { 0 => input_items }

        if (handled_outputs = continued_error_outputs(waiting_node, input_groups, error))
          handled_outputs = enforce_node_output_budget(handled_outputs, nil)
          all_items = handled_outputs.flatten(1)
          step&.add_metadata("handled_error", error_metadata(error))
          step&.succeed!(output: all_items)
          step&.apply_updates!("error" => nil)
          @context.store_node_output(waiting_node, all_items)
          @context.store_node_run(
            waiting_node,
            inputs: [input_items],
            outputs: handled_outputs,
            input_sources: @context.consume_waiting_input_sources,
          )
          clear_waiting!
          route_downstream(waiting_node, handled_outputs)
        else
          step&.fail!(error.message)
          raise error
        end
      end
    end

    private

    def step_mode?
      @options.step_node_id.present?
    end

    def prepare_step_flow!
      step_node = @snapshot.find_node(@options.step_node_id)
      raise "Step node #{@options.step_node_id} not found in workflow snapshot" if step_node.nil?

      @pin_data_by_node_name.delete(step_node.name.to_s)
      @step_plan =
        StepExecutionPlan.new(
          snapshot: @snapshot,
          target: step_node,
          run_data: @store.existing_run_data,
        )

      if @step_plan.standalone_target?
        @queue << [step_node, { 0 => [Item.wrap({})] }, {}]
        return
      end

      @step_plan.cached_frontier.each { |node| emit_cached_node!(node) }
      @step_plan.trigger_roots_to_run.each { |trigger_node| seed_trigger_node!(trigger_node) }
    end

    def emit_cached_node!(node)
      output_groups = @step_plan.cached_outputs(node)
      step = record_step(node, [])
      step.succeed!(output: output_groups.flatten(1))
      step.add_metadata("cached", true)
      route_downstream(node, output_groups)
    end

    def seed_trigger_node!(trigger_node)
      trigger_items =
        pinned_items_for(trigger_node) ||
          (
            if @trigger_data.is_a?(Array)
              @trigger_data.map { |data| Item.wrap(data) }
            else
              [Item.wrap(@trigger_data)]
            end
          )
      ItemContract.validate_items!(trigger_items, source: "trigger:#{trigger_node.type}")
      record_step(trigger_node, [], output: trigger_items, status: Step::SUCCESS)
      @context.store_node_output(trigger_node, trigger_items)
      @context.store_node_run(trigger_node, inputs: [], outputs: [trigger_items])
      enqueue_downstream(trigger_node, 0, trigger_items)
    end

    def normalized_workflow_call_stack
      stack = Array(@options.workflow_call_stack).map(&:to_s)
      workflow_id = @workflow.id.to_s
      stack.last == workflow_id ? stack : stack + [workflow_id]
    end

    def execute_flow(setup_method, *setup_args, &block)
      send(setup_method, *setup_args)
      yield
      process_queue
      @store.finish!(steps: @steps)
    rescue ExecutionPaused => e
      begin_wait!(e.wait_request)
    rescue => e
      @store.fail!(error: e, steps: @steps)
    ensure
      commit_static_data!
      @sandbox&.dispose
    end

    # Persists any static_data mutations made by action nodes during the run.
    # Skipped when no node ever called `get_workflow_static_data` (the state
    # tracks a dirty flag). Reloads under a row lock so we don't clobber
    # concurrent executions that wrote to other nodes' flat `node:<name>` slots.
    def commit_static_data!
      state = @context&.static_data_state
      return unless state&.dirty?

      @workflow.with_lock do
        @workflow.reload
        existing_node_data = @workflow.node_static_data_entries
        changed_node_data =
          state
            .node
            .each_with_object({}) do |(node_name, node_data), result|
              next if node_data.blank? && !existing_node_data.key?(node_name)

              result[node_name] = node_data
            end
        merged_node = existing_node_data.merge(changed_node_data)
        @workflow.commit_static_data!(global: state.global, node: merged_node)
      end
    rescue => e
      Rails.logger.warn(
        "discourse-workflows: failed to commit static_data for workflow " \
          "#{@workflow.id}: #{e.class}: #{e.message}",
      )
    end

    def process_queue
      iterations = 0
      @queue_index = 0

      loop do
        while @queue_index < @queue.length
          iterations += 1
          raise "Max iterations (#{MAX_ITERATIONS}) exceeded" if iterations > MAX_ITERATIONS

          node, input_groups, input_sources = @queue[@queue_index]
          @queue_index += 1
          execute_node(node, input_groups, input_sources || {})
        end

        break unless flush_partial_waiting_inputs
      end
    end

    def execute_node(node, input_groups, input_sources = {})
      input_items = primary_input_items(input_groups)
      node_type_class =
        DiscourseWorkflows::Registry.find_node_type(node.type, version: node.type_version)
      return handle_unknown_node(node, input_items) unless node_type_class

      unless node_type_class.available?
        return handle_unavailable_node(node, node_type_class, input_items)
      end

      if (pinned = pinned_items_for(node, node_type_class:))
        return(handle_pinned_node(node, input_items, input_groups, input_sources, pinned))
      end

      issues = NodeIssues.for_node(node, node_type_class)
      return handle_node_issues(node, input_items, issues) if issues.any?

      step = record_step(node, input_items)
      capture_operation_metadata(step, node, node_type_class)
      js_elapsed_before = sandbox_budget_tracker.current_elapsed_ms
      node_context = @context.node_context_for(node)
      resolver_ctx = build_resolver_context(node, input_groups, node_context, input_sources)
      resolver = build_resolver(resolver_ctx)
      runtime_state = NodeExecutionContext::RuntimeState.new

      exec_ctx = nil
      begin
        exec_ctx =
          build_node_execution_context(
            node,
            input_groups,
            node_context,
            node_type_class,
            resolver,
            resolver_ctx,
            runtime_state,
          )
        result =
          node_type_class.new(
            parameters: node.parameters,
            credentials: node.credentials,
            webhook_id: node.webhook_id,
          ).execute(exec_ctx)

        attach_form_completion(step, node, resolver)

        wait_request = runtime_state.wait_request
        if wait_request
          if step_mode?
            raise StandardError, I18n.t("discourse_workflows.errors.step_execution.wait_requested")
          end

          step.mark_waiting!
          @waiting_node = node
          @waiting_step = step
          @context.store_waiting_input_sources(
            input_sources_for_storage(input_sources, input_groups),
          )
          raise ExecutionPaused, wait_request
        end

        step_log = collect_step_log(exec_ctx, resolver)
        if step_log&.errors?
          attach_step_log(step, step_log)
          step.fail!(step_log.error_summary)
          raise StandardError, step.error
        end

        ports = node_type_class.ports(node.parameters)
        output_arrays = normalize_result(result, node, ports, input_groups)
        output_arrays = apply_always_output_data(output_arrays, node, input_groups)
        output_arrays = enforce_node_output_budget(output_arrays, step_log)
        attach_step_log(step, step_log)
        all_items = output_arrays.flatten(1)
        primary_empty = output_arrays.fetch(0) { [] }.empty?

        if node_type_class.branching? && primary_empty
          step.filter!(output: all_items)
        else
          step.succeed!(output: all_items)
        end

        @context.store_node_output(node, all_items)
        @context.store_node_run(
          node,
          inputs: input_groups_for_storage(input_groups),
          outputs: output_arrays,
          input_sources: input_sources_for_storage(input_sources, input_groups),
        )
        route_downstream(node, output_arrays)
      rescue ExecutionPaused
        raise
      rescue => e
        if (handled_outputs = continued_error_outputs(node, input_groups, e))
          step_log = collect_step_log(exec_ctx, resolver)
          handled_outputs = enforce_node_output_budget(handled_outputs, step_log)
          attach_step_log(step, step_log)
          step.add_metadata("handled_error", error_metadata(e))
          all_items = handled_outputs.flatten(1)
          step.succeed!(output: all_items)
          step.apply_updates!("error" => nil)
          @context.store_node_output(node, all_items)
          @context.store_node_run(
            node,
            inputs: input_groups_for_storage(input_groups),
            outputs: handled_outputs,
            input_sources: input_sources_for_storage(input_sources, input_groups),
          )
          route_downstream(node, handled_outputs)
          return
        end

        unless step.metadata&.key?("logs")
          attach_step_log(step, collect_step_log(exec_ctx, resolver))
        end

        step.fail!(e.message) unless step.error?
        raise
      ensure
        resolver&.dispose
        js_elapsed = (sandbox_budget_tracker.current_elapsed_ms - js_elapsed_before).round(1)
        step.add_metadata("js_elapsed_ms", js_elapsed) if js_elapsed > 0
        runtime_state.step_metadata.each { |key, value| step.add_metadata(key, value) }
      end
    end

    def collect_step_log(exec_ctx, resolver)
      return unless exec_ctx

      log = exec_ctx.log || StepLog.new
      errors = resolver&.expression_errors || []
      errors.each { |err| log.error("#{err[:expression]}: #{err[:error]}") } if errors.present?
      log
    end

    def attach_step_log(step, step_log)
      return if step_log.nil? || step_log.empty?

      step.add_metadata("logs", step_log.as_json)
    end

    def attach_form_completion(step, node, resolver)
      return unless DiscourseWorkflows::FormCompletion.completion_node?(node)

      step.add_metadata(
        DiscourseWorkflows::FormCompletion::METADATA_KEY,
        DiscourseWorkflows::FormCompletion.for_node(node, resolver: resolver),
      )
    end

    def handle_unknown_node(node, input_items)
      Rails.logger.warn(
        "discourse-workflows: unknown node type '#{node.type}' (version: #{node.type_version}) " \
          "in workflow #{@context.workflow.id}, skipping node '#{node.name}'",
      )
      record_step(node, input_items, status: Step::ERROR, error: "Unknown node type '#{node.type}'")
    end

    def handle_unavailable_node(node, node_type_class, input_items)
      reason = node_type_class.unavailable_reason_key || "discourse_workflows.node_unavailable"
      Rails.logger.warn(
        "discourse-workflows: node type '#{node.type}' is unavailable " \
          "in workflow #{@context.workflow.id}, passing through node '#{node.name}'",
      )
      step = record_step(node, input_items)
      step.skip!(output: input_items, reason: reason)
      @context.store_node_output(node, input_items)
      @context.store_node_run(node, inputs: [input_items], outputs: [input_items])
      enqueue_downstream(node, 0, input_items)
    end

    def handle_node_issues(node, input_items, issues)
      reason = issues.map { |i| "#{i[:path]}: #{i[:message]}" }.join(", ")
      step = record_step(node, input_items)
      step.skip!(output: input_items, reason: reason)
      @context.store_node_output(node, input_items)
      @context.store_node_run(node, inputs: [input_items], outputs: [input_items])
      enqueue_downstream(node, 0, input_items)
    end

    def handle_pinned_node(node, input_items, input_groups, input_sources, pinned_items)
      step = record_step(node, input_items)
      step.succeed!(output: pinned_items)
      step.add_metadata("pinned", true)
      @context.store_node_output(node, pinned_items)
      @context.store_node_run(
        node,
        inputs: input_groups_for_storage(input_groups),
        outputs: [pinned_items],
        input_sources: input_sources_for_storage(input_sources, input_groups),
      )
      enqueue_downstream(node, 0, pinned_items)
    end

    # Returns pinned items for this node when:
    #   - the run is in :manual mode (pin data is never used in :normal mode),
    #   - the workflow has pin data for this node name,
    #   - the node type has a single primary output.
    # Returns nil otherwise.
    def pinned_items_for(node, node_type_class: nil)
      return nil if @pin_data_by_node_name.empty?

      raw_items = @pin_data_by_node_name[node.name.to_s]
      return nil if raw_items.blank?

      node_type_class ||=
        DiscourseWorkflows::Registry.find_node_type(node.type, version: node.type_version)
      return nil if node_type_class.nil?
      return nil if Array(node_type_class.outputs).length > 1

      Item.normalize_items(raw_items)
    rescue Item::InconsistentItemFormatError
      nil
    end

    def resolved_pin_data
      return {} unless @options.execution_mode == :manual

      data =
        if @options.workflow_snapshot
          @options.workflow_snapshot.pin_data
        elsif @workflow.respond_to?(:pin_data)
          @workflow.pin_data
        end
      return {} if data.blank?

      data.transform_keys(&:to_s)
    end

    def build_node_execution_context(
      node,
      input_groups,
      node_context,
      node_type_class,
      resolver,
      resolver_ctx,
      runtime_state
    )
      NodeExecutionContext.new(
        input_items: primary_input_items(input_groups),
        input_groups: input_groups,
        parameters: node.parameters,
        credentials: node.credentials,
        node_settings: DiscourseWorkflows::NodeData.direct_settings(node),
        webhook_id: node.webhook_id,
        property_schema: node_type_class.property_schema,
        credential_schema: node_type_class.credentials,
        node_context: node_context,
        user: @options.user,
        resolver: resolver,
        vars: preloaded_vars,
        workflow: @workflow,
        workflow_version: @options.workflow_version,
        execution_id: @store.execution&.id,
        resume_token: @context.resume_token,
        node_id: node.id.to_s,
        node_name: node.name.to_s,
        node_identifier: node.type,
        execution_mode: @options.execution_mode,
        flow_context: @context.context,
        resolver_context: resolver_ctx,
        workflow_dependencies: preloaded_workflow_dependencies,
        workflow_snapshot: @snapshot,
        webhook_context: @options.webhook_context,
        workflow_call_stack: @workflow_call_stack,
        runtime_state: runtime_state,
        static_data_state: @context.static_data_state,
      )
    end

    def normalize_result(result, node, ports, input_groups)
      source = "#{node.name} (#{node.type})"
      ItemContract.validate_output_arrays!(result, source: source, ports: ports)

      apply_item_linking_defaults!(result, input_groups:)
      ItemContract.validate_output_arrays!(result, source: source, ports: ports)
      result
    end

    def enforce_node_output_budget(output_arrays, step_log)
      total_bytes = 0
      truncated = false

      bounded_arrays =
        output_arrays.map do |items|
          bounded_items = []

          items.each do |item|
            item_bytes = JSON.generate(item).bytesize

            if total_bytes + item_bytes > MAX_NODE_OUTPUT_BYTES
              truncated = true
              break
            end

            total_bytes += item_bytes
            bounded_items << item
          end

          bounded_items
        end

      if truncated
        step_log&.warn(
          "Node output truncated at #{bounded_arrays.flatten(1).length} items because serialized " \
            "output exceeded #{MAX_NODE_OUTPUT_BYTES} bytes",
        )
      end

      bounded_arrays
    end

    def apply_item_linking_defaults!(output_arrays, input_groups:)
      input_lookup = input_item_lookup(input_groups)
      sole_input_pair = sole_input_pair(input_groups)
      primary_items = primary_input_items(input_groups)
      one_output = output_arrays.length == 1

      output_arrays.each do |items|
        items.each_with_index do |item, index|
          pair =
            if input_lookup.key?(item.object_id)
              input_lookup[item.object_id]
            elsif Item.paired_item(item).present?
              Item.paired_item(item)
            elsif sole_input_pair
              sole_input_pair
            elsif one_output && index < primary_items.length && items.length == primary_items.length
              pair_for(input: 0, item: index)
            end

          items[index] = Item.with_paired_item(item, pair) if pair.present?
        end
      end
    end

    def input_item_lookup(input_groups)
      input_groups.each_with_object({}) do |(input_index, items), lookup|
        items.each_with_index do |item, item_index|
          lookup[item.object_id] = pair_for(input: input_index, item: item_index)
        end
      end
    end

    def sole_input_pair(input_groups)
      pairs =
        input_groups.flat_map do |input_index, items|
          items.each_index.map { |item_index| pair_for(input: input_index, item: item_index) }
        end
      pairs.one? ? pairs.first : nil
    end

    def pair_for(input:, item:, include_input: false)
      pair = { "item" => item }
      pair["input"] = input if include_input || input != 0
      pair
    end

    def apply_always_output_data(output_arrays, node, input_groups)
      return output_arrays unless always_output_data?(node)
      return output_arrays if output_arrays.fetch(0) { [] }.any?

      pairs =
        input_groups.flat_map do |input_index, items|
          items.each_index.map do |item_index|
            pair_for(input: input_index, item: item_index, include_input: true)
          end
        end
      synthetic = { "json" => {}, "pairedItem" => pairs }

      output_arrays = output_arrays.dup
      output_arrays[0] = [synthetic]
      output_arrays
    end

    def always_output_data?(node)
      ActiveModel::Type::Boolean.new.cast(
        DiscourseWorkflows::NodeData.read(node, "alwaysOutputData"),
      ) == true
    end

    def continued_error_outputs(node, input_groups, error)
      case node_error_mode(node)
      when "continueRegularOutput"
        [primary_input_items(input_groups)]
      when "continueErrorOutput"
        [[], error_output_items(primary_input_items(input_groups), error)]
      end
    end

    def node_error_mode(node)
      on_error = DiscourseWorkflows::NodeData.read(node, "onError").presence
      return on_error if %w[continueRegularOutput continueErrorOutput].include?(on_error)
      return "stopWorkflow" if on_error == "stopWorkflow"
      return if on_error.present?

      if ActiveModel::Type::Boolean.new.cast(
           DiscourseWorkflows::NodeData.read(node, "continueOnFail"),
         ) == true
        "continueRegularOutput"
      end
    end

    def error_output_items(input_items, error)
      metadata = error_metadata(error)
      return [{ "json" => {}, "error" => metadata }] if input_items.empty?

      input_items.map.with_index do |item, index|
        item.deep_dup.merge("error" => metadata, "pairedItem" => pair_for(input: 0, item: index))
      end
    end

    def error_metadata(error)
      { "message" => error.message, "name" => error.class.name }
    end

    def route_downstream(node, output_arrays)
      output_arrays.each_with_index { |items, index| enqueue_downstream(node, index, items) }
    end

    def enqueue_downstream(node, output_index, items)
      return if step_mode? && node.id.to_s == @step_plan.target_id

      @snapshot
        .connections_from_output_index(node, output_index)
        .each do |conn|
          target = @snapshot.target_node(conn)
          next if target.nil?
          next if step_mode? && !@step_plan.runnable?(target)

          enqueue_target(
            target,
            conn.target_input_index,
            items,
            source: {
              "node_name" => node.name,
              "output_index" => output_index,
            },
          )
        end
    end

    def enqueue_target(target, target_input_index, items, source:)
      target_input_index = target_input_index.to_i
      requirements = input_wait_requirements(target)
      inputs_to_wait_for = requirements[:inputs_to_wait_for]

      if requirements[:minimum_input_count]
        return enqueue_minimum_input_target(target, target_input_index, items, source, requirements)
      end

      if inputs_to_wait_for.length <= 1
        return if items.empty?

        @queue << [target, { 0 => items }, { 0 => source }]
        return
      end

      inputs = (@waiting_inputs[target.id] ||= {})
      sources = (@waiting_input_sources[target.id] ||= {})
      @waiting_input_targets[target.id] = target
      inputs[target_input_index] = items
      sources[target_input_index] = source

      return unless inputs_to_wait_for.all? { |index| inputs.key?(index) }

      @waiting_inputs.delete(target.id)
      @waiting_input_sources.delete(target.id)
      @waiting_input_targets.delete(target.id)
      @queue << [target, inputs, sources]
    end

    def enqueue_minimum_input_target(target, target_input_index, items, source, requirements)
      inputs = (@waiting_inputs[target.id] ||= {})
      sources = (@waiting_input_sources[target.id] ||= {})
      @waiting_input_targets[target.id] = target
      inputs[target_input_index] = items
      sources[target_input_index] = source

      connected_inputs = requirements[:connected_inputs]
      if connected_inputs.length <= requirements[:minimum_input_count] ||
           connected_inputs.all? { |index| inputs.key?(index) }
        return enqueue_waiting_input_target(target)
      end

      return if available_input_count(inputs) >= requirements[:minimum_input_count]

      @waiting_inputs.delete(target.id)
      @waiting_input_sources.delete(target.id)
      @waiting_input_targets.delete(target.id)
    end

    def enqueue_waiting_input_target(target)
      inputs = @waiting_inputs.delete(target.id) || {}
      sources = @waiting_input_sources.delete(target.id) || {}
      @waiting_input_targets.delete(target.id)
      return if available_input_count(inputs).zero?

      @queue << [target, inputs, sources]
    end

    def flush_partial_waiting_inputs
      queued_any = false
      waiting_target_ids = @waiting_input_targets.keys
      @waiting_input_targets.dup.each_value do |target|
        requirements = input_wait_requirements(target)
        next unless requirements[:minimum_input_count]
        next if waiting_input_parent?(target, waiting_target_ids)

        inputs = @waiting_inputs[target.id] || {}
        next if available_input_count(inputs) < requirements[:minimum_input_count]

        enqueue_waiting_input_target(target)
        queued_any = true
      end
      queued_any
    end

    def available_input_count(inputs)
      inputs.count { |_index, items| items.present? }
    end

    def waiting_input_parent?(target, waiting_target_ids)
      @snapshot
        .connections_to(target)
        .any? { |conn| waiting_target_ids.include?(conn.source_node_id.to_s) }
    end

    def input_wait_requirements(target)
      @input_wait_requirements[target.id] ||= begin
        node_type_class =
          DiscourseWorkflows::Registry.find_node_type(target.type, version: target.type_version)
        input_ports =
          node_type_class&.input_ports(target.parameters) ||
            [{ key: "main", index: 0, required: true }]
        explicit_required_inputs = node_type_class&.required_inputs(target.parameters)
        required_inputs = input_ports.select { |port| port[:required] }.map { |port| port[:index] }
        connected_inputs = @snapshot.connections_to(target).map(&:target_input_index).uniq

        if explicit_required_inputs.is_a?(Integer)
          {
            connected_inputs: connected_inputs,
            inputs_to_wait_for: [],
            minimum_input_count: explicit_required_inputs,
          }
        elsif explicit_required_inputs.present?
          {
            connected_inputs: connected_inputs,
            inputs_to_wait_for: Array(explicit_required_inputs).map(&:to_i),
          }
        else
          {
            connected_inputs: connected_inputs,
            inputs_to_wait_for: (required_inputs + connected_inputs).uniq,
          }
        end
      end
    end

    def primary_input_items(input_groups)
      input_groups.fetch(0) { input_groups.values.first || [] }
    end

    def input_groups_for_storage(input_groups)
      max_index = input_groups.keys.max || 0
      Array.new(max_index + 1) { |index| input_groups[index] || [] }
    end

    def input_sources_for_storage(input_sources, input_groups)
      max_index = [input_groups.keys.max || 0, input_sources.keys.max || 0].max
      Array.new(max_index + 1) { |index| input_sources[index] || {} }
    end

    def capture_operation_metadata(step, node, node_type_class)
      properties = node_type_class.properties
      return unless properties.is_a?(Hash) && properties.key?(:operation)

      operation_value = node.parameters&.dig("operation") || node.parameters&.dig(:operation)
      return if operation_value.blank?

      step.add_metadata("operation", operation_value)
    end

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
      if step.nil?
        Rails.logger.warn(
          "discourse-workflows: waiting step not found for node '#{waiting_node.id}' " \
            "in workflow #{@context.workflow.id}",
        )
        return
      end
      step.apply_updates!(
        "status" => Step::SUCCESS,
        "output" => response_items,
        "finished_at" => Time.current.iso8601,
      )
    end

    def begin_wait!(wait_request)
      store_pending_wait_state!

      if wait_request.workflow_call?
        begin_workflow_call_wait!(wait_request)
      else
        begin_timed_wait!(wait_request.waiting_until)
      end
    rescue => e
      @store.fail!(error: e, steps: @steps)
    end

    def store_pending_wait_state!
      @context.store_pending_input_groups(
        inputs: @waiting_inputs,
        sources: @waiting_input_sources,
        target_ids: @waiting_input_targets.keys,
      )
      @context.store_pending_queue(@queue.drop(@queue_index || 0))
    end

    def begin_timed_wait!(waiting_until)
      now = Time.current
      ceiling = now + MAX_WAIT_DURATION_SECONDS
      resolved = waiting_until.blank? ? ceiling : [waiting_until, ceiling].min

      execution =
        @store.pause_waiting_execution!(node: @waiting_node, waiting_until: resolved, steps: @steps)

      Jobs.enqueue_in(
        [resolved - now, 0].max,
        Jobs::DiscourseWorkflows::ResumeWaitingExecution,
        execution_id: @store.execution.id,
      )
      execution
    end

    def begin_workflow_call_wait!(wait_request)
      execution = @store.pause_waiting_execution!(node: @waiting_node, steps: @steps)

      DiscourseWorkflows::WorkflowCallContinuation.begin_child_call!(
        execution: execution,
        node: @waiting_node,
        request: wait_request,
      )
      execution
    end

    def start_execution!
      @store.start!
      @snapshot = @store.workflow_snapshot
      @steps = []
      @queue = []
      @queue_index = 0
      @waiting_inputs = {}
      @waiting_input_sources = {}
      @waiting_input_targets = {}
      @input_wait_requirements = {}
    end

    def resume_execution!(execution)
      @store.resume!(execution)
      @snapshot = @store.workflow_snapshot
      @steps = restore_steps_from(execution)
      @queue = []
      @queue_index = 0
      @waiting_inputs = {}
      @waiting_input_sources = {}
      @waiting_input_targets = {}
      @input_wait_requirements = {}
      restore_pending_queue!
      restore_pending_input_groups!
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

    def restore_pending_input_groups!
      @context.consume_pending_input_groups.each do |target_id, payload|
        target = @snapshot.find_node(target_id)
        next if target.nil?

        @waiting_input_targets[target.id] = target
        @waiting_inputs[target.id] = indexed_values_from_payload(payload["inputs"], "items")
        @waiting_input_sources[target.id] = indexed_values_from_payload(
          payload["sources"],
          "source",
        )
      end
    end

    def restore_pending_queue!
      @queue =
        @context.consume_pending_queue.filter_map do |payload|
          node = @snapshot.find_node(payload["node_id"])
          next if node.nil?

          [
            node,
            indexed_values_from_payload(payload["inputs"], "items"),
            indexed_values_from_payload(payload["sources"], "source"),
          ]
        end
    end

    def indexed_values_from_payload(payload, value_key)
      Array(payload).each_with_object({}) do |entry, values|
        values[entry["index"].to_i] = entry[value_key]
      end
    end

    def build_resolver_context(node, input_groups, node_context, input_sources)
      input_items = primary_input_items(input_groups)
      current_item = input_items.first || { "json" => {} }
      base =
        @context.resolver_context(
          "__input_item" => current_item,
          "__input_items" => input_items,
          "__input_params" => node.parameters,
          "__input_context" => DiscourseWorkflows::InputContext.from_node_context(node_context),
          "__current_node_id" => node.id.to_s,
          "__node_parameters_by_name" => node_parameters_by_name,
          "$itemIndex" => 0,
        )
      base["__input_sources"] = input_sources_for_storage(input_sources, input_groups)
      base.merge("$json" => current_item.fetch("json") { {} })
    end

    def node_parameters_by_name
      @node_parameters_by_name ||=
        @snapshot
          .nodes
          .each_with_object({}) do |node, by_name|
            name = node.name.to_s
            next if name.blank?

            by_name[name] = by_name.key?(name) ? nil : node.parameters
          end
          .compact
    end

    def build_resolver(resolver_ctx)
      ExpressionResolver.new(resolver_ctx, user: @options.user, sandbox: shared_sandbox)
    end

    def shared_sandbox
      @sandbox ||=
        DiscourseWorkflows::JsSandbox.new(
          @context.resolver_context,
          user: @options.user,
          vars: preloaded_vars,
          budget_tracker: sandbox_budget_tracker,
        )
    end

    def preloaded_vars
      @preloaded_vars ||= DiscourseWorkflows::Variable.pluck(:key, :value).to_h
    end

    def preloaded_workflow_dependencies
      @preloaded_workflow_dependencies ||=
        @snapshot
          .nodes
          .each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |node, dependencies|
            node_dependencies(node).each do |type, key|
              dependencies[node.id.to_s] << "#{type}:#{key}"
            end
          end
    end

    def node_dependencies(node)
      parameters = NodeData.parameters(node)
      credentials =
        NodeData.split(
          parameters: parameters,
          credentials: NodeData.credentials(node),
          node_type: node.type,
        )[
          "credentials"
        ]
      dependencies = []
      credentials.each_value do |credential|
        dependencies << ["credential_id", credential["id"]] if credential["id"].present?
      end
      if parameters["data_table_id"].present?
        dependencies << ["data_table_id", parameters["data_table_id"]]
      end
      if node.type == DiscourseWorkflows::Nodes::WorkflowCall::V1.identifier &&
           parameters["workflow_id"].present?
        dependencies << ["workflow_call", parameters["workflow_id"]]
      end
      dependencies
    end

    def sandbox_budget_tracker
      @sandbox_budget_tracker ||= DiscourseWorkflows::SandboxBudget.new(@context.context)
    end

    def rate_limiter
      @rate_limiter ||= ExecutionRateLimiter.new(@workflow)
    end
  end
end
