# frozen_string_literal: true

module DiscourseWorkflows
  class NodeView
    attr_reader :id,
                :name,
                :type,
                :type_version,
                :position,
                :webhook_id,
                :notes,
                :notes_in_flow,
                :always_output_data,
                :on_error,
                :continue_on_fail

    def self.from_snapshot_node(
      node,
      include_node_parameters: false,
      include_credentials: false,
      include_webhook_id: false
    )
      return if node.blank?

      direct_settings =
        DiscourseWorkflows::NodeData
          .direct_settings(node)
          .transform_keys { |key| DiscourseWorkflows::NodeData::NODE_DIRECT_SETTING_KEYS[key] }

      new(
        id: node.id,
        name: node.name,
        type: node.type,
        type_version: node.type_version,
        position: node.position,
        webhook_id: include_webhook_id ? node.webhook_id : nil,
        parameters: include_node_parameters ? node.parameters : nil,
        credentials: include_credentials ? node.credentials : nil,
        **direct_settings,
      )
    end

    def initialize(
      id:,
      name:,
      type:,
      type_version:,
      position: nil,
      webhook_id: nil,
      parameters: nil,
      credentials: nil,
      notes: nil,
      notes_in_flow: nil,
      always_output_data: nil,
      on_error: nil,
      continue_on_fail: nil
    )
      @id = id.to_s
      @name = name.to_s
      @type = type.to_s
      @type_version = numeric_version(type_version)
      @position = position || [0, 0]
      @webhook_id = webhook_id
      @parameters = parameters&.deep_dup
      @credentials = credentials&.deep_dup
      @notes = notes
      @notes_in_flow = notes_in_flow
      @always_output_data = always_output_data
      @on_error = on_error
      @continue_on_fail = continue_on_fail
      freeze
    end

    def parameters
      @parameters&.deep_dup
    end

    def credentials
      @credentials&.deep_dup
    end

    def to_h
      {
        "id" => id,
        "name" => name,
        "type" => type,
        "typeVersion" => type_version,
        "position" => position,
        "webhookId" => webhook_id,
        "parameters" => parameters,
        "credentials" => credentials,
      }.merge(DiscourseWorkflows::NodeData.direct_settings(self)).compact
    end

    private

    def numeric_version(version)
      Float(version)
    rescue ArgumentError, TypeError
      version
    end
  end
end
