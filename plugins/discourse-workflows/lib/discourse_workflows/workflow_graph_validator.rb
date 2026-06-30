# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowGraphValidator
    MAX_NODES = 50
    UNSUPPORTED_NODE_KEYS = %i[type_version webhook_id position_index settings].freeze
    STICKY_NOTE_TYPE = "flow:sticky_note"

    attr_reader :workflow

    def initialize(workflow:, nodes_data:, connections_data:)
      @workflow = workflow
      @nodes_data = nodes_data || []
      @connections_data = connections_data || {}
    end

    def valid?
      validate_payload_shape
      return false if workflow.errors.any?

      validate_node_fields
      return false if workflow.errors.any?

      validate_node_count
      validate_node_json_keys
      validate_unique_node_names
      validate_node_type_limits
      return false if workflow.errors.any?

      existing_nodes_index = workflow.nodes.index_by { |n| n["id"] }

      normalized_nodes_data.each do |node_data|
        existing = existing_nodes_index[node_data[:id].to_s]
        type_version = resolve_type_version(node_data, existing)
        validate_node_type(node_data, type_version)
        validate_node_version(node_data, type_version)
      end

      return false if workflow.errors.any?

      validate_connections
      validate_workflow_call_dependencies
      workflow.errors.empty?
    end

    def nodes
      node_map.values
    end

    def connections
      DiscourseWorkflows::WorkflowDocument.normalize_connections(nodes, connections_data)
    end

    private

    attr_reader :nodes_data, :connections_data

    def validate_payload_shape
      unless nodes_data.is_a?(Array)
        workflow.errors.add(:base, I18n.t("discourse_workflows.errors.invalid_nodes"))
      end

      if nodes_data.is_a?(Array) && nodes_data.any? { |node| !node.is_a?(Hash) }
        workflow.errors.add(:base, I18n.t("discourse_workflows.errors.invalid_nodes"))
      end

      unless connections_data.is_a?(Hash)
        workflow.errors.add(:base, I18n.t("discourse_workflows.errors.invalid_connections"))
      end
    end

    def validate_node_fields
      normalized_nodes_data.each do |node_data|
        validate_node_type_presence(node_data)
        validate_node_name_presence(node_data)
        validate_node_hash_field(node_data, :parameters)
        validate_node_hash_field(node_data, :credentials)
      end
    end

    def validate_node_type_presence(node_data)
      return if node_data[:type].present?

      workflow.errors.add(:base, I18n.t("discourse_workflows.errors.node_types_required"))
    end

    def validate_node_name_presence(node_data)
      return if node_data[:name].present?

      workflow.errors.add(:base, I18n.t("discourse_workflows.errors.node_names_required"))
    end

    def validate_node_hash_field(node_data, field)
      return if node_data[field].nil? || node_data[field].is_a?(Hash)

      workflow.errors.add(:base, I18n.t("discourse_workflows.errors.invalid_node_fields"))
    end

    def validate_node_count
      if normalized_nodes_data.size > MAX_NODES
        workflow.errors.add(
          :base,
          I18n.t("discourse_workflows.errors.max_nodes_exceeded", max: MAX_NODES),
        )
      end
    end

    def validate_node_json_keys
      return if normalized_nodes_data.none? { |node_data| unsupported_node_key?(node_data) }

      workflow.errors.add(:base, I18n.t("discourse_workflows.errors.invalid_node_json_keys"))
    end

    def unsupported_node_key?(node_data)
      (node_data.keys & UNSUPPORTED_NODE_KEYS).present?
    end

    def validate_unique_node_names
      executable_names =
        normalized_nodes_data
          .reject { |node_data| sticky_note?(node_data) }
          .map { |node_data| node_data[:name].to_s }
      sticky_note_names =
        normalized_nodes_data
          .select { |node_data| sticky_note?(node_data) }
          .map { |node_data| node_data[:name].to_s }

      duplicate_names = executable_names.tally.select { |_name, count| count > 1 }.keys
      duplicate_names += sticky_note_names & executable_names
      duplicate_names = duplicate_names.uniq

      return if duplicate_names.empty?

      workflow.errors.add(
        :base,
        I18n.t(
          "discourse_workflows.errors.duplicate_node_names",
          names: duplicate_names.join(", "),
        ),
      )
    end

    def sticky_note?(node_data)
      node_data[:type] == STICKY_NOTE_TYPE
    end

    def validate_node_type_limits
      normalized_nodes_data
        .group_by { |node_data| node_data[:type] }
        .each do |type, nodes|
          node_type_class = DiscourseWorkflows::Registry.find_node_type(type)
          max_nodes = node_type_class&.max_nodes
          next if max_nodes.blank? || nodes.size <= max_nodes

          workflow.errors.add(
            :base,
            I18n.t("discourse_workflows.errors.max_nodes_of_type_exceeded", max: max_nodes, type:),
          )
        end
    end

    def validate_node_type(node_data, type_version)
      node_type_class =
        DiscourseWorkflows::Registry.find_node_type(
          node_data[:type],
          version: type_version,
          include_disabled_plugins: true,
        )
      parameters = split_node_data(node_data, existing: nil)[:parameters]

      if node_type_class.respond_to?(:validate_configuration)
        node_type_class.validate_configuration(parameters, workflow.errors)
      end
    end

    def validate_node_version(node_data, type_version)
      if DiscourseWorkflows::Registry.available_versions(
           node_data[:type],
           include_disabled_plugins: true,
         ).exclude?(type_version)
        workflow.errors.add(
          :base,
          I18n.t(
            "discourse_workflows.errors.unsupported_node_version",
            version: type_version,
            type: node_data[:type],
          ),
        )
      end
    end

    def validate_connections
      connection_records.each do |connection_data|
        target =
          node_map.values.find { |node| node["id"].to_s == connection_data["target_node_id"].to_s }
        next if target.blank?

        target_type =
          DiscourseWorkflows::Registry.find_node_type(
            target["type"],
            version: target["typeVersion"],
            include_disabled_plugins: true,
          )
        next if target_type&.inputs(target["parameters"]).present?

        workflow.errors.add(
          :base,
          I18n.t("discourse_workflows.errors.node_does_not_accept_inputs", node: target["name"]),
        )
      end
    end

    def validate_workflow_call_dependencies
      calls = workflow_call_nodes
      return if calls.empty?

      target_ids = calls.filter_map { |node| workflow_call_target_id(node) }
      targets_by_id =
        DiscourseWorkflows::Workflow.includes(:active_version).where(id: target_ids).index_by(&:id)

      calls.each do |node|
        validate_workflow_call_target(node, targets_by_id[workflow_call_target_id(node)])
      end

      validate_workflow_call_cycles(calls) if workflow.errors.empty?
    end

    def validate_workflow_call_target(node, target_workflow)
      target_id = workflow_call_target_id(node)
      return if target_id.blank?

      if workflow.id.present? && target_id == workflow.id
        return add_call_error(:self_reference, node: node["name"])
      end

      return add_call_error(:target_not_found) if target_workflow.nil?
      return if target_workflow.callable_as_subworkflow?

      add_call_error(:target_not_callable)
    end

    def validate_workflow_call_cycles(calls)
      return if workflow.id.blank?

      edges = active_workflow_call_edges
      edges[workflow.id] = calls.filter_map { |node| workflow_call_target_id(node) }.to_set

      calls.each do |node|
        target_id = workflow_call_target_id(node)
        next if target_id.blank?

        next unless workflow_call_reaches?(target_id, workflow.id, edges, Set.new)

        add_call_error(:cycle, node: node["name"])
      end
    end

    def add_call_error(key, **args)
      workflow.errors.add(:base, I18n.t("discourse_workflows.errors.workflow_call.#{key}", **args))
    end

    def workflow_call_nodes
      nodes.select { |node| node["type"] == DiscourseWorkflows::Nodes::WorkflowCall::V1.identifier }
    end

    def workflow_call_target_id(node)
      to_workflow_id(DiscourseWorkflows::NodeData.parameters(node)["workflow_id"])
    end

    def to_workflow_id(value)
      Integer(value, exception: false) if value.present?
    end

    def active_workflow_call_edges
      DiscourseWorkflows::WorkflowDependency
        .of_type("workflow_call")
        .on_active_version
        .pluck(:workflow_id, :dependency_key)
        .each_with_object(
          Hash.new { |hash, key| hash[key] = Set.new },
        ) do |(source_id, target_key), edges|
          target_id = to_workflow_id(target_key)
          edges[source_id] << target_id if target_id
        end
    end

    def workflow_call_reaches?(start_id, target_id, edges, visited)
      return true if start_id == target_id
      return false unless visited.add?(start_id)

      edges[start_id].any? { |next_id| workflow_call_reaches?(next_id, target_id, edges, visited) }
    end

    def connection_records
      DiscourseWorkflows::WorkflowDocument.connection_records(nodes, connections_data)
    end

    def node_map
      @node_map ||= build_node_map
    end

    def build_node_map
      existing_nodes = workflow.nodes.index_by { |n| n["id"] }
      node_map = {}

      normalized_nodes_data.each do |node_data|
        node_id = (node_data[:id].presence || SecureRandom.uuid).to_s
        existing = existing_nodes[node_id]
        node_map[node_id] = build_node_hash(node_data, node_id:, existing:)
      end

      node_map
    end

    def build_node_hash(node_data, node_id:, existing:)
      node_data = split_node_data(node_data, existing:)

      {
        "id" => existing ? existing["id"] : (node_id.presence || SecureRandom.uuid),
        "type" => node_data[:type],
        "typeVersion" => resolve_type_version(node_data, existing),
        "name" => node_data[:name],
        "position" => node_data[:position],
        "parameters" => node_data[:parameters],
        "credentials" => node_data[:credentials],
        "webhookId" => node_data[:webhookId],
      }.merge(node_data[:directSettings])
    end

    def resolve_type_version(node_data, existing)
      existing&.dig("typeVersion") || node_data[:typeVersion] ||
        DiscourseWorkflows::Registry.latest_version(node_data[:type]) ||
        DiscourseWorkflows::Registry::DEFAULT_VERSION
    end

    def normalized_nodes_data
      @normalized_nodes_data ||= nodes_data.map(&:symbolize_keys)
    end

    def split_node_data(node_data, existing:)
      split =
        NodeData.split(
          parameters: node_data[:parameters],
          credentials: node_data[:credentials],
          webhook_id: resolved_webhook_id(node_data, existing: existing),
          node_type: node_data[:type],
        )

      node_data.merge(
        parameters: split["parameters"],
        credentials: split["credentials"],
        webhookId: split[DiscourseWorkflows::WorkflowDocument.node_webhook_id_key],
        directSettings: NodeData.direct_settings(node_data),
      )
    end

    def resolved_webhook_id(node_data, existing:)
      return node_data[:webhookId].presence if node_data[:webhookId].present?
      return existing["webhookId"] if existing&.dig("webhookId").present?
      SecureRandom.uuid if node_data[:type] == NodeDataShape::FORM_TRIGGER_TYPE
    end
  end
end
