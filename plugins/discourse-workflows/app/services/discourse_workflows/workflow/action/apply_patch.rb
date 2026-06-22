# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::ApplyPatch < Service::ActionBase
    AI_AGENT_NODE_TYPE = "action:ai_agent"
    AI_AGENT_REF_KEY = "$ref"
    AI_AGENT_REF_PREFIX = "$agent:"
    CREATE_AI_AGENT_OPERATION = "create_ai_agent"
    AI_AGENT_ALLOWED_KEYS = %w[name description system_prompt].freeze

    option :workflow
    option :operations
    option :persist, default: -> { false }
    option :user, optional: true

    def call
      result = build_candidate
      return result if !result[:valid]

      return result if !persist

      workflow_version = nil
      created_ai_agents_by_client_id = {}
      workflow.transaction do
        created_ai_agents_by_client_id = create_ai_agents!(result[:ai_agent_definitions])
        rewrite_ai_agent_references!(result[:nodes], created_ai_agents_by_client_id)
        workflow.update!(nodes: result[:nodes], connections: result[:connections], updated_by: user)
        workflow_version =
          workflow.snapshot!(user: user || workflow.updated_by || workflow.created_by)
        WorkflowDependencyIndexer.call(workflow.reload, version: workflow_version)
      end
      Workflow::Action::ExpireCaches.call
      result[:created_resources] = created_ai_agent_resources(created_ai_agents_by_client_id)
      result
    end

    private

    def build_candidate
      state = initial_state
      Array
        .wrap(operations)
        .each { |operation| apply_operation!(state, normalize_operation!(operation)) }
      validate_ai_agent_node_references!(state)
      validate_state(state)
    rescue PatchError => e
      invalid_result([e.message])
    end

    def initial_state
      nodes = deep_copy(workflow.nodes || [])
      {
        nodes: nodes,
        node_ids_by_client_id: {
        },
        connection_records:
          DiscourseWorkflows::WorkflowDocument.connection_records(
            nodes,
            deep_copy(workflow.connections || {}),
          ),
        ai_agent_definitions: {
        },
      }
    end

    def normalize_operation!(operation)
      normalize_hash!(operation, "Patch operation must be an object")
    end

    def normalize_hash!(value, message)
      raise PatchError, message if !value.respond_to?(:to_h)

      value.to_h.with_indifferent_access
    rescue TypeError
      raise PatchError, message
    end

    def apply_operation!(state, operation)
      case operation[:op].to_s
      when "add_node"
        add_node!(state, operation)
      when "update_node_parameters"
        update_node_parameters!(state, operation)
      when "rename_node"
        rename_node!(state, operation)
      when "remove_node"
        remove_node!(state, operation)
      when "add_connection"
        add_connection!(state, operation)
      when "remove_connection"
        remove_connection!(state, operation)
      when CREATE_AI_AGENT_OPERATION
        create_ai_agent_definition!(state, operation)
      else
        raise PatchError, "Unsupported patch operation: #{operation[:op]}"
      end
    end

    def add_node!(state, operation)
      node_data = normalize_hash!(operation[:node], "Node payload must be an object")
      node_type = node_data[:type].presence || raise(PatchError, "Node type is required")
      name = node_data[:name].presence || raise(PatchError, "Node name is required")
      node_id = SecureRandom.uuid
      client_id = operation[:client_id].presence
      state[:node_ids_by_client_id][client_id] = node_id if client_id

      state[:nodes] << {
        "id" => node_id,
        "type" => node_type,
        "typeVersion" => node_type_version(node_data[:typeVersion], node_type),
        "name" => name,
        "parameters" => node_data[:parameters] || {},
        "credentials" => node_credentials(node_data[:credentials]),
        "webhookId" => node_data[:webhookId],
        "position" => node_position(node_data[:position]),
      }
    end

    def node_position(position)
      return { "x" => 0, "y" => 0 } if position.blank?

      return { "x" => position[0].to_f, "y" => position[1].to_f } if position.is_a?(Array)

      normalize_hash!(position, "Node position must be an object or [x, y] array")
    end

    def node_credentials(credentials)
      return {} if credentials.blank?

      normalize_hash!(credentials, "Credentials must be an object")
    end

    def node_type_version(type_version, node_type)
      version = type_version.presence || latest_version(node_type)
      version = version.to_s
      version.include?(".") ? version : "#{version}.0"
    end

    def update_node_parameters!(state, operation)
      node = find_node!(state, operation)
      parameters = normalize_hash!(operation[:parameters], "Parameters must be an object")
      node["parameters"] = (node["parameters"] || {}).merge(parameters)
    end

    def rename_node!(state, operation)
      node = find_node!(state, operation)
      node["name"] = operation[:name].presence || raise(PatchError, "Node name is required")
    end

    def remove_node!(state, operation)
      node = find_node!(state, operation)
      state[:nodes].delete(node)
      state[:connection_records].reject! do |connection|
        connection["source_node_id"] == node["id"] || connection["target_node_id"] == node["id"]
      end
    end

    def add_connection!(state, operation)
      source_node_id = resolve_node_ref!(state, operation[:from] || operation[:from_node_id])
      target_node_id = resolve_node_ref!(state, operation[:to] || operation[:to_node_id])
      state[:connection_records] << {
        "source_node_id" => source_node_id,
        "source_output_index" => operation[:output_index].to_i,
        "target_node_id" => target_node_id,
        "target_input_index" => operation[:input_index].to_i,
        "connection_type" => operation[:connection_type].presence || "main",
      }
    end

    def remove_connection!(state, operation)
      source_node_id = resolve_node_ref!(state, operation[:from] || operation[:from_node_id])
      target_node_id = resolve_node_ref!(state, operation[:to] || operation[:to_node_id])
      state[:connection_records].reject! do |connection|
        connection["source_node_id"] == source_node_id &&
          connection["target_node_id"] == target_node_id &&
          (
            operation[:output_index].blank? ||
              connection["source_output_index"] == operation[:output_index].to_i
          ) &&
          (
            operation[:input_index].blank? ||
              connection["target_input_index"] == operation[:input_index].to_i
          )
      end
    end

    def create_ai_agent_definition!(state, operation)
      ensure_ai_agent_available!

      client_id =
        operation[:client_id].presence || raise(PatchError, "AI agent client_id is required")
      if state[:ai_agent_definitions].key?(client_id)
        raise PatchError, "Duplicate AI agent client_id: #{client_id}"
      end

      agent_data =
        normalize_hash!(
          operation[:agent] || operation[:ai_agent],
          "AI agent payload must be an object",
        )
      unsupported_keys = agent_data.keys.map(&:to_s) - AI_AGENT_ALLOWED_KEYS
      if unsupported_keys.present?
        raise PatchError,
              "AI agent payload includes unsupported fields: #{unsupported_keys.join(", ")}"
      end

      attributes = ai_agent_attributes(agent_data)
      validate_unique_ai_agent_name!(state, attributes)
      validate_ai_agent_attributes!(client_id, attributes)
      state[:ai_agent_definitions][client_id] = attributes
    end

    def validate_unique_ai_agent_name!(state, attributes)
      duplicate =
        state[:ai_agent_definitions].values.find do |existing_attributes|
          existing_attributes["name"].casecmp?(attributes["name"])
        end
      return if duplicate.blank?

      raise PatchError, "Duplicate proposed AI agent name: #{attributes["name"]}"
    end

    def ai_agent_attributes(agent_data)
      {
        "name" => agent_data[:name].to_s.strip,
        "description" => agent_data[:description].to_s.strip,
        "system_prompt" => agent_data[:system_prompt].to_s.strip,
        "enabled" => true,
        "tools" => [],
        "allowed_group_ids" => [],
        "show_thinking" => false,
      }
    end

    def validate_ai_agent_attributes!(client_id, attributes)
      agent = ::AiAgent.new(attributes.merge("created_by" => ai_agent_creator))
      return if agent.valid?

      raise PatchError,
            "AI agent #{client_id.inspect} is invalid: #{agent.errors.full_messages.join(", ")}"
    end

    def validate_ai_agent_node_references!(state)
      state[:nodes].each do |node|
        next if node["type"] != AI_AGENT_NODE_TYPE

        parameters = node["parameters"] || {}
        agent_id = parameters["agent_id"] || parameters[:agent_id]
        agent_ref = ai_agent_ref(agent_id)

        if agent_ref.present?
          validate_ai_agent_ref!(node, parameters, state[:ai_agent_definitions], agent_ref)
        else
          validate_existing_ai_agent!(node, parameters, agent_id)
        end
      end
    end

    def validate_ai_agent_ref!(node, parameters, definitions, agent_ref)
      definition = definitions[agent_ref]
      if definition.blank?
        raise PatchError,
              "#{node_label(node)} references unknown AI agent client_id #{agent_ref.inspect}"
      end

      parameters["agent_name"] ||= definition["name"]
    end

    def validate_existing_ai_agent!(node, parameters, agent_id)
      if agent_id.blank?
        raise PatchError,
              "#{node_label(node)} must set agent_id to an existing AI agent ID or a proposed AI agent reference"
      end

      ensure_ai_agent_available!
      agent = ::AiAgent.find_by(id: agent_id.to_i)
      if agent.blank?
        raise PatchError, "#{node_label(node)} references missing AI agent ID #{agent_id.inspect}"
      end
      if !agent.enabled?
        raise PatchError, "#{node_label(node)} references disabled AI agent #{agent.name.inspect}"
      end

      parameters["agent_name"] ||= agent.name
    end

    def ai_agent_ref(value)
      if value.respond_to?(:to_h)
        value.to_h[AI_AGENT_REF_KEY].presence
      elsif value.is_a?(String) && value.start_with?(AI_AGENT_REF_PREFIX)
        value.delete_prefix(AI_AGENT_REF_PREFIX).presence
      end
    end

    def ensure_ai_agent_available!
      return if defined?(::AiAgent)

      raise PatchError, "AI agent operations require Discourse AI"
    end

    def node_label(node)
      node["name"].presence || node["id"].presence || node["type"]
    end

    def validate_state(state)
      connections =
        DiscourseWorkflows::WorkflowDocument.connections_from_records(
          state[:nodes],
          state[:connection_records],
        )
      candidate = workflow.dup
      candidate.nodes = state[:nodes]
      candidate.connections = connections
      validator =
        DiscourseWorkflows::WorkflowGraphValidator.new(
          workflow: candidate,
          nodes_data: state[:nodes],
          connections_data: connections,
        )

      return invalid_result(candidate.errors.full_messages) if !validator.valid?

      {
        valid: true,
        errors: [],
        nodes: validator.nodes,
        connections: validator.connections,
        diff: diff_summary,
        ai_agent_definitions: state[:ai_agent_definitions],
        created_resources: created_ai_agent_definition_resources(state[:ai_agent_definitions]),
      }
    end

    def diff_summary
      counts =
        Array.wrap(operations).map { |operation| operation.to_h["op"] || operation.to_h[:op] }.tally
      { operation_counts: counts, operation_count: counts.values.sum }
    end

    def invalid_result(errors)
      { valid: false, errors: Array.wrap(errors), nodes: nil, connections: nil, diff: nil }
    end

    def create_ai_agents!(definitions)
      definitions.each_with_object({}) do |(client_id, attributes), created_agents|
        created_agents[client_id] = ::AiAgent.create!(
          attributes.merge("created_by" => ai_agent_creator),
        )
      end
    end

    def ai_agent_creator
      user || Discourse.system_user
    end

    def rewrite_ai_agent_references!(nodes, created_ai_agents_by_client_id)
      return if created_ai_agents_by_client_id.blank?

      nodes.each do |node|
        next if node["type"] != AI_AGENT_NODE_TYPE

        parameters = node["parameters"] || {}
        agent_ref = ai_agent_ref(parameters["agent_id"] || parameters[:agent_id])
        next if agent_ref.blank?

        agent = created_ai_agents_by_client_id[agent_ref]
        next if agent.blank?

        parameters["agent_id"] = agent.id
        parameters["agent_name"] = agent.name
      end
    end

    def created_ai_agent_definition_resources(definitions)
      definitions.map do |client_id, attributes|
        {
          "type" => "ai_agent",
          "client_id" => client_id,
          "name" => attributes["name"],
          "description" => attributes["description"],
          "system_prompt" => attributes["system_prompt"],
        }
      end
    end

    def created_ai_agent_resources(created_ai_agents_by_client_id)
      created_ai_agents_by_client_id.map do |client_id, agent|
        {
          "type" => "ai_agent",
          "client_id" => client_id,
          "id" => agent.id,
          "name" => agent.name,
          "description" => agent.description,
          "system_prompt" => agent.system_prompt,
        }
      end
    end

    def find_node!(state, operation)
      node_id = resolve_node_ref!(state, operation[:node_id] || operation[:client_id])
      state[:nodes].find { |node| node["id"].to_s == node_id.to_s } ||
        raise(PatchError, "Node not found: #{node_id}")
    end

    def resolve_node_ref!(state, ref)
      ref = ref.to_s
      raise PatchError, "Node reference is required" if ref.blank?

      state[:node_ids_by_client_id][ref] || ref
    end

    def latest_version(node_type)
      DiscourseWorkflows::Registry.latest_version(node_type) ||
        DiscourseWorkflows::Registry::DEFAULT_VERSION
    end

    def deep_copy(value)
      JSON.parse(JSON.generate(value))
    end

    class PatchError < StandardError
    end
  end
end
