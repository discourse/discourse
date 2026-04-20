# frozen_string_literal: true

module DiscourseWorkflows
  class NodeTypeSerializer
    def initialize(identifier:, latest_class:, latest_version:, available_versions:)
      @identifier = identifier
      @latest_class = latest_class
      @latest_version = latest_version
      @available_versions = available_versions
    end

    def to_h
      ui = @latest_class.ui_metadata
      capabilities = @latest_class.capabilities

      {
        identifier: @identifier,
        kind: @latest_class.kind,
        latest_version: @latest_version,
        available_versions: @available_versions,
        property_schema: @latest_class.property_schema,
        property_schema_versions: property_schema_versions,
        output_schema: output_schema,
        metadata: metadata,
        ui: ui,
        capabilities: capabilities,
        ports: @latest_class.ports,
        operations: @latest_class.operations,
        icon: ui[:icon],
        color: ui[:color],
        branching: capabilities[:branching],
        manually_triggerable: capabilities[:manually_triggerable],
        available: @latest_class.available?,
        unavailable_reason_key:
          (@latest_class.unavailable_reason_key unless @latest_class.available?),
      }.compact
    end

    private

    def property_schema_versions
      return if @available_versions.size <= 1

      @available_versions.to_h do |version|
        [version, Registry.find_node_type(@identifier, version: version).property_schema]
      end
    end

    def output_schema
      @latest_class.respond_to?(:output_schema) ? @latest_class.output_schema : {}
    end

    def metadata
      meta = @latest_class.respond_to?(:metadata) ? @latest_class.metadata : {}
      meta || {}
    end
  end
end
