# frozen_string_literal: true

module DiscourseWorkflows
  module NodeData
    NODE_DIRECT_SETTING_KEYS = NodeDataShape::NODE_DIRECT_SETTING_KEYS

    module_function

    def parameters(node)
      read(node, "parameters") || {}
    end

    def credentials(node)
      read(node, "credentials") || {}
    end

    def resolved_parameters(node)
      parameters(node).deep_dup
    end

    def type_version(node)
      WorkflowDocument.node_type_version(node) || Registry::DEFAULT_VERSION
    end

    def webhook_id(node)
      WorkflowDocument.node_webhook_id(node)
    end

    def split(parameters:, credentials: {}, webhook_id: nil, node_type: nil)
      parameters = (parameters || {}).deep_stringify_keys
      credentials = normalize_credentials(credentials)

      credentials = filter_declared_credentials(credentials, node_type, parameters)

      {
        "parameters" => parameters,
        "credentials" => credentials,
        WorkflowDocument.node_webhook_id_key => webhook_id,
      }
    end

    def direct_settings(node)
      NODE_DIRECT_SETTING_KEYS.each_with_object({}) do |(json_key, _attribute), settings|
        value = read(node, json_key)
        settings[json_key] = value unless value.nil?
      end
    end

    def normalize_credentials(credentials_hash)
      (credentials_hash || {}).each_with_object({}) do |(slot, credential), result|
        next unless credential.is_a?(Hash)

        credential = credential.deep_stringify_keys
        next if credential["id"].blank?

        result[slot.to_s] = credential.slice("id", "credential_type").merge(
          "id" => credential["id"].to_s,
        )
      end
    end

    def read(node, key)
      return node.public_send(key) if node.respond_to?(key)

      attribute = NODE_DIRECT_SETTING_KEYS[key.to_s]
      return node.public_send(attribute) if attribute && node.respond_to?(attribute)

      if node.respond_to?(:key?)
        return node[key] if node.key?(key)
        key_symbol = key.to_sym
        return node[key_symbol] if node.key?(key_symbol)
      end

      node[key] || node[key.to_sym]
    end

    def filter_declared_credentials(credentials, node_type, parameters)
      return credentials if node_type.blank?

      definitions = credential_definitions_for(node_type)
      return {} if definitions.blank?

      definitions.each_with_object({}) do |definition, result|
        slot = definition["name"]
        credential = credentials[slot]
        next if credential.blank? || !credential_slot_visible?(definition, parameters)

        credential_type = credential["credential_type"].presence
        credential_types = credential_types_for(definition)
        credential_type ||= credential_types.first if credential_types.one?
        next if credential_type.blank? || credential_types.exclude?(credential_type)

        result[slot] = credential.merge("credential_type" => credential_type)
      end
    end

    def credential_definitions_for(node_type)
      normalize_credential_definitions(node_class(node_type)&.credentials)
    end

    def normalize_credential_definitions(definitions)
      Array(definitions).filter_map do |definition|
        definition = definition.deep_stringify_keys
        name = definition["name"].presence
        next if name.blank?

        definition.merge("name" => name)
      end
    end

    def credential_types_for(definition)
      Array(definition["credential_types"] || definition["credential_type"]).map(&:to_s)
    end

    def credential_slot_visible?(definition, parameters)
      display_options = definition["display_options"] || {}

      visible_for_conditions?(display_options["show"], parameters) &&
        !hidden_by_conditions?(display_options["hide"], parameters)
    end

    def visible_for_conditions?(conditions, parameters)
      return true if conditions.blank?

      conditions.all? { |key, expected| matches_display_rule?(expected, parameters[key]) }
    end

    def hidden_by_conditions?(conditions, parameters)
      conditions.present? && visible_for_conditions?(conditions, parameters)
    end

    def matches_display_rule?(expected, value)
      return false unless expected.is_a?(Array)

      expected.any? { |condition| matches_display_condition?(condition, value) }
    end

    def matches_display_condition?(condition, value)
      operator = condition.is_a?(Hash) ? condition["condition"] : nil
      return condition == value if operator.blank?

      return value != operator["not"] if operator.key?("not")
      if operator.key?("exists")
        return operator["exists"] ? !empty_display_value?(value) : empty_display_value?(value)
      end

      false
    end

    def empty_display_value?(value)
      return true if value.nil? || value == ""
      return value.empty? if value.is_a?(Array)
      false
    end

    def node_class(node_type)
      node_type.respond_to?(:identifier) ? node_type : Registry.find_node_type(node_type)
    end
  end
end
