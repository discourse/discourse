# frozen_string_literal: true

module DiscourseWorkflows
  class LoadOptionsContext
    attr_reader :method_name,
                :property_name,
                :node_identifier,
                :node_version,
                :node_id,
                :node_name,
                :workflow_id,
                :credentials,
                :filter,
                :input_context,
                :execution_context,
                :user,
                :guardian,
                :node_class

    def initialize(
      method_name:,
      property_name: nil,
      node_identifier: nil,
      node_version: nil,
      node_id: nil,
      node_name: nil,
      workflow_id: nil,
      parameters: {},
      credentials: {},
      filter: nil,
      input_context: {},
      execution_context: {},
      user: nil,
      guardian: nil,
      node_class: nil
    )
      @method_name = method_name.to_s
      @property_name = property_name.presence&.to_s
      @node_identifier = node_identifier.presence&.to_s || node_class&.identifier
      @node_version = node_version.presence&.to_s || node_class&.version
      @node_id = node_id.presence&.to_s
      @node_name = node_name.presence&.to_s
      @workflow_id = workflow_id.presence&.to_s
      @parameters = normalize_hash(parameters)
      @node_class = node_class
      @credentials = filter_credentials(credentials)
      @filter = filter.presence&.to_s
      @input_context = normalize_hash(input_context)
      @execution_context = normalize_hash(execution_context)
      @user = user
      @guardian = guardian
    end

    def get_current_node_parameter(path = nil, fallback = nil)
      return @parameters if path.blank?

      value = dig_path(@parameters, path)
      value.nil? ? fallback : value
    end

    def get_current_node_parameters
      @parameters
    end

    def matches_filter?(value)
      filter.blank? || value.downcase.include?(filter.downcase)
    end

    def get_credentials(slot)
      definition = credential_definition(slot)
      credential = credential_for_slot(slot)
      raise Discourse::InvalidAccess if definition.blank? || credential.blank?

      credential_record = DiscourseWorkflows::Credential.find_by(id: credential["id"])
      raise Discourse::InvalidAccess if credential_record.blank?
      unless credential_type_allowed?(definition, credential_record.credential_type)
        raise Discourse::InvalidAccess
      end

      DiscourseWorkflows::ExpressionResolver.resolve_hash(
        credential_record.data || {},
        context: credential_resolver_context,
        user: user,
      )
    end

    def helpers
      @helpers ||= ContextHelpers.new(node_identifier: node_identifier, guardian: guardian)
    end

    def to_h
      {
        method_name: method_name,
        property_name: property_name,
        node_identifier: node_identifier,
        node_version: node_version,
        node_id: node_id,
        node_name: node_name,
        workflow_id: workflow_id,
        parameters: @parameters,
        credentials: credentials,
        filter: filter,
        input_context: input_context,
        execution_context: execution_context,
      }.compact
    end

    private

    def normalize_hash(value)
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      value = value.to_h if value.respond_to?(:to_h)
      value.is_a?(Hash) ? value.deep_stringify_keys : {}
    end

    def filter_credentials(credentials)
      NodeData.filter_declared_credentials(
        NodeData.normalize_credentials(normalize_hash(credentials)),
        node_class,
        @parameters,
      )
    end

    def credential_definitions
      @credential_definitions ||= NodeData.normalize_credential_definitions(node_class&.credentials)
    end

    def credential_definition(slot)
      credential_definitions.find { |definition| definition["name"] == slot.to_s } ||
        credential_definitions.find do |definition|
          NodeData.credential_types_for(definition).include?(slot.to_s)
        end
    end

    def credential_for_slot(slot)
      credentials[slot.to_s].presence || credentials[credential_definition(slot)&.fetch("name")]
    end

    def credential_type_allowed?(definition, credential_type)
      NodeData.credential_types_for(definition).include?(credential_type.to_s)
    end

    def credential_resolver_context
      execution_context.merge(input_context).merge(
        "$json" => input_context.dig("item", "json") || {},
        "__input_item" => input_context["item"] || {},
      )
    end

    def dig_path(hash, path)
      path
        .to_s
        .split(".")
        .reject(&:blank?)
        .reduce(hash) do |value, key|
          break nil unless value.respond_to?(:[])

          if value.respond_to?(:key?) && value.key?(key)
            value[key]
          elsif value.respond_to?(:key?) && value.key?(key.to_sym)
            value[key.to_sym]
          end
        end
    end
  end
end
