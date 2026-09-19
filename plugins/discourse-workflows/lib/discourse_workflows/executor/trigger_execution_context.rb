# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class TriggerExecutionContext
      MISSING = Object.new.freeze
      MAX_DEDUPLICATION_KEYS = 200

      class RuntimeState
        attr_reader :collected_trigger_data, :trigger_state, :static_data_global, :static_data_node

        def initialize(trigger_state:, static_data_global: {}, static_data_node: {}, tick: false)
          @collected_trigger_data = []
          @trigger_state = trigger_state || {}
          @static_data_global = static_data_global || {}
          @static_data_node = static_data_node || {}
          @tick = tick
        end

        def tick?
          @tick
        end

        def deduplicated?(deduplication_key)
          deduplication_key.present? &&
            Array.wrap(@trigger_state["triggered_occurrences"]).include?(deduplication_key)
        end

        def record_deduplication_key(deduplication_key, now:)
          keys = Array.wrap(@trigger_state["triggered_occurrences"])
          @trigger_state["triggered_occurrences"] = keys.last(MAX_DEDUPLICATION_KEYS - 1) +
            [deduplication_key]
          @trigger_state["last_triggered_at"] = now.utc.iso8601
        end

        def collect_trigger_data(trigger_data)
          @collected_trigger_data << trigger_data
        end
      end

      attr_reader :now, :node_id

      def initialize(
        published_trigger:,
        mode: :normal,
        activation_mode: :init,
        now: Time.current.utc,
        dispatch: :enqueue,
        user: nil,
        runtime_state:
      )
        @published_trigger = published_trigger
        @mode = mode.to_s
        @activation_mode = activation_mode.to_s
        @now = now
        @dispatch = dispatch
        @user = user
        @node_id = published_trigger.trigger_node_id.to_s
        @snapshot = WorkflowSnapshot.from_version(workflow, workflow_version)
        @runtime_state = runtime_state
      end

      def get_node_parameter(parameter_name, default = nil, _options = {})
        value = parameter_value(parameter_name)
        value.equal?(MISSING) ? default : value
      end

      def get_timezone
        DiscourseWorkflows::WorkflowTimezone.for(workflow:, workflow_version:)
      end

      def get_workflow_static_data(type)
        case type.to_s
        when "node"
          @runtime_state.static_data_node
        when "global"
          @runtime_state.static_data_global
        else
          raise ArgumentError, "Unknown static data scope: #{type.inspect}. Use :node or :global"
        end
      end

      def get_mode
        @mode
      end

      def get_activation_mode
        @activation_mode
      end

      def get_workflow
        WorkflowView.from_workflow(workflow, name: workflow_version.name)
      end

      def get_node
        NodeView.from_snapshot_node(
          @snapshot.find_node(node_id),
          include_node_parameters: true,
          include_credentials: true,
          include_webhook_id: true,
        )
      end

      def get_child_nodes(node_name, options = {})
        graph_nodes(
          @snapshot.child_nodes(node_name, connection_type: "main", depth: -1),
          include_node_parameters: graph_option(options, :include_node_parameters, false),
        )
      end

      def get_parent_nodes(node_name, options = {})
        graph_nodes(
          @snapshot.parent_nodes(
            node_name,
            connection_type: graph_option(options, :connection_type, "main"),
            depth: graph_option(options, :depth, -1),
          ),
          include_node_parameters: graph_option(options, :include_node_parameters, false),
        )
      end

      def workflow_id
        workflow.id
      end

      def helpers
        @helpers ||= Helpers.new(self, @runtime_state)
      end

      def emit(data, deduplication_key: nil)
        trigger_data = trigger_data_from(data)
        return if trigger_data.blank?
        return if @runtime_state.deduplicated?(deduplication_key)

        if deduplication_key.present?
          @runtime_state.record_deduplication_key(deduplication_key, now: now)
        end

        case @dispatch
        when :enqueue
          DiscourseWorkflows::TriggerDispatcher.enqueue(@published_trigger, trigger_data:)
        when :execute
          DiscourseWorkflows::TriggerDispatcher.execute(
            @published_trigger,
            trigger_data:,
            user: @user,
          )
        when :collect
          @runtime_state.collect_trigger_data(trigger_data)
        when :none
          nil
        end
      end

      private

      def workflow
        @published_trigger.workflow
      end

      def workflow_version
        @published_trigger.workflow_version
      end

      def graph_nodes(nodes, include_node_parameters:)
        Array
          .wrap(nodes)
          .filter_map do |node|
            NodeView.from_snapshot_node(node, include_node_parameters: include_node_parameters)
          end
      end

      def graph_option(options, key, default)
        options = {} unless options.respond_to?(:[])
        options[key] || options[key.to_s] || default
      end

      def parameters
        @parameters ||= DiscourseWorkflows::NodeData.parameters(@published_trigger.trigger_node)
      end

      def parameter_value(parameter_name)
        segments = parameter_name.to_s.split(".").reject(&:blank?)
        return MISSING if segments.empty?

        segments.reduce(parameters) do |current, segment|
          case current
          when Hash
            current.fetch(segment) { current.fetch(segment.to_sym, MISSING) }
          when Array
            return MISSING unless segment.match?(/\A\d+\z/)

            current.fetch(segment.to_i) { return MISSING }
          else
            return MISSING
          end
        end
      end

      def trigger_data_from(data)
        output_arrays = Array.wrap(data)
        first_output = output_arrays.first
        first_item = Array.wrap(first_output).first

        if first_item.is_a?(Hash) && first_item.key?("json")
          first_item["json"]
        elsif first_item.is_a?(Hash)
          first_item.deep_stringify_keys
        else
          {}
        end
      end

      class Helpers
        def initialize(context, runtime_state)
          @context = context
          @runtime_state = runtime_state
        end

        def return_json_array(json_data)
          Array.wrap(json_data).map { |data| DiscourseWorkflows::Item.wrap(data) }
        end

        def register_cron(cron)
          return unless @runtime_state.tick?

          expression = cron[:expression] || cron["expression"]
          scheduled_time = @context.now.in_time_zone(@context.get_timezone)
          return unless DiscourseWorkflows::CronParser.matches?(expression, scheduled_time)

          yield @context.now if block_given?
        end
      end
    end
  end
end
