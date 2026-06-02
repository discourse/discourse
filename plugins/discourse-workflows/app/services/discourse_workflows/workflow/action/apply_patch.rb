# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::ApplyPatch < Service::ActionBase
    option :workflow
    option :operations
    option :persist, default: -> { false }
    option :user, optional: true

    def call
      result = build_candidate
      return result if !result[:valid]

      return result if !persist

      workflow_version = nil
      workflow.transaction do
        workflow.update!(nodes: result[:nodes], connections: result[:connections], updated_by: user)
        workflow_version =
          workflow.snapshot!(user: user || workflow.updated_by || workflow.created_by)
        WorkflowDependencyIndexer.call(workflow.reload, version: workflow_version)
      end
      Workflow::Action::ExpireCaches.call
      result
    end

    private

    def build_candidate
      state = initial_state
      Array
        .wrap(operations)
        .each { |operation| apply_operation!(state, normalize_operation!(operation)) }
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
        "position" => node_data[:position] || { "x" => 0, "y" => 0 },
      }
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
