# frozen_string_literal: true

module DiscourseWorkflows
  class StepExecutionPlan
    COMPLETED_RUN_STATUSES = [
      Executor::Step::SUCCESS,
      Executor::Step::FILTERED,
      Executor::Step::SKIPPED,
    ].freeze

    def self.run_matches_node?(run, node)
      run_node_id = run["node_id"]
      return false if run_node_id.present? && run_node_id.to_s != node.id.to_s

      run_node_type = run["node_type"]
      return false if run_node_type.present? && run_node_type != node.type

      true
    end

    attr_reader :target

    def initialize(snapshot:, target:, run_data:)
      @snapshot = snapshot
      @target = target
      @run_data = run_data || {}
      @nodes_by_id = upstream_closure
      @classifications = @nodes_by_id.transform_values { |node| classify(node) }
      @producible = {}
    end

    def target_id
      @target.id.to_s
    end

    def standalone_target?
      @snapshot.connections_to(@target).empty?
    end

    def runnable?(node)
      @classifications[node.id.to_s] == :execute
    end

    def executable_nodes
      @nodes_by_id.values.select { |node| runnable?(node) }
    end

    def trigger_roots_to_run
      executable_nodes.select { |node| trigger?(node) }
    end

    def cached_frontier
      @nodes_by_id
        .values
        .select { |node| @classifications[node.id.to_s] == :cached }
        .select { |node| all_outbound_connections(node).any? { |conn| feeds_runnable?(conn) } }
    end

    def target_reachable?
      standalone_target? || inputs_satisfiable?(@target)
    end

    def cached_outputs(node)
      pinned_output_groups(node) || run_output_groups(node) || []
    end

    private

    def upstream_closure
      closure = { @target.id.to_s => @target }
      queue = [@target]

      while (node = queue.shift)
        @snapshot
          .connections_to(node)
          .each do |connection|
            source = @snapshot.source_node(connection)
            next if source.nil? || closure.key?(source.id.to_s)

            closure[source.id.to_s] = source
            queue << source
          end
      end

      closure
    end

    def classify(node)
      return :execute if node.id.to_s == target_id
      return :cached if cached_outputs(node).present?

      return manually_triggerable?(node) ? :execute : :unavailable if trigger?(node)

      @snapshot.connections_to(node).empty? ? :unavailable : :execute
    end

    def trigger?(node)
      node.type.to_s.start_with?("trigger:")
    end

    def manually_triggerable?(node)
      node_type_class(node)&.manually_triggerable? == true
    end

    def node_type_class(node)
      Registry.find_node_type(node.type, version: node.type_version)
    end

    def all_outbound_connections(node)
      @snapshot.connections.select { |conn| conn.source_node_id == node.id.to_s }
    end

    def feeds_runnable?(connection)
      target_node = @snapshot.target_node(connection)
      target_node.present? && runnable?(target_node)
    end

    def producible?(node)
      node_id = node.id.to_s
      return @producible[node_id] if @producible.key?(node_id)

      # Break cycles (e.g. loop-back edges): a node cannot vouch for itself.
      @producible[node_id] = false

      @producible[node_id] = case @classifications[node_id]
      when :cached
        true
      when :execute
        trigger?(node) || standalone?(node) || inputs_satisfiable?(node)
      else
        false
      end
    end

    def standalone?(node)
      @snapshot.connections_to(node).empty?
    end

    def inputs_satisfiable?(node)
      satisfied, unsatisfied =
        @snapshot
          .connections_to(node)
          .group_by { |connection| connection.target_input_index.to_i }
          .partition do |_index, connections|
            connections.any? do |connection|
              source = @snapshot.source_node(connection)
              source.present? && producible?(source)
            end
          end

      return true if unsatisfied.empty?

      requirements = node_type_class(node)&.required_inputs(node.parameters)
      if requirements.is_a?(Integer)
        satisfied.length >= requirements
      elsif requirements.present?
        required = Array(requirements).map(&:to_i)
        unsatisfied.none? { |index, _connections| required.include?(index) }
      else
        false
      end
    end

    def pinned_output_groups(node)
      raw_items = (@snapshot.pin_data || {})[node.name.to_s]
      return nil if raw_items.blank?

      node_type_class = node_type_class(node)
      return nil if node_type_class.nil?
      return nil if Array(node_type_class.outputs).length > 1

      [Item.normalize_items(raw_items)]
    rescue Item::InconsistentItemFormatError
      nil
    end

    def run_output_groups(node)
      run =
        Array(@run_data[node.name.to_s]).reverse_each.find do |entry|
          COMPLETED_RUN_STATUSES.include?(entry["status"]) &&
            self.class.run_matches_node?(entry, node)
        end
      return nil if run.nil?

      ports = Array(run["outputs"])
      max_index = ports.map { |port| port["index"].to_i }.max
      return nil if max_index.nil?

      groups = Array.new(max_index + 1) { [] }
      ports.each { |port| groups[port["index"].to_i] = Array(port["items"]) }
      groups
    end
  end
end
