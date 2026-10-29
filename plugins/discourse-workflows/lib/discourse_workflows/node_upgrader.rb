# frozen_string_literal: true

module DiscourseWorkflows
  # Moves saved nodes on a deprecated version to what `NodeType.upgrade` returns. A node keeps its id, name,
  # position, credentials and settings, so connections, expressions and pinned data still find it.
  class NodeUpgrader
    Upgrade = Data.define(:name, :from, :to, :notes)
    Result = Data.define(:nodes, :upgrades, :skipped)

    def self.call(nodes)
      upgrades = []
      skipped = []

      nodes =
        Array(nodes).map do |node|
          node_class = NodeData.node_type(node)
          next node if !node_class&.deprecated?

          upgraded, notes = upgrade(node, node_class)
          if upgraded.nil?
            skipped << node["name"]
            next node
          end

          upgrades << Upgrade.new(
            name: node["name"],
            from: type_and_version(node),
            to: type_and_version(upgraded),
            notes: notes.map { |key| I18n.t(key) },
          )
          upgraded
        end

      Result.new(nodes:, upgrades:, skipped:)
    end

    def self.upgrade(node, node_class)
      parameters = NodeData.parameters(node)
      target = node_class.upgrade(parameters)
      return if target.nil?

      type = target.fetch(:type)
      version = target[:version] || target_version(type, node_class)
      target_class = Registry.find_node_type(type, version:)
      return if target_class.nil? || target_class.deprecated?

      target_parameters = target.fetch(:parameters).deep_stringify_keys
      # Connections are stored per output port, so a different number of ports would drop or misplace them.
      return if target_class.ports(target_parameters).length != node_class.ports(parameters).length

      upgraded =
        node.merge("type" => type, "typeVersion" => version, "parameters" => target_parameters)
      [upgraded, Array(target[:notes])]
    end
    private_class_method :upgrade

    def self.target_version(type, node_class)
      superseded_by = node_class.deprecation[:superseded_by] if type == node_class.identifier
      superseded_by || Registry.latest_version(type)
    end
    private_class_method :target_version

    def self.type_and_version(node)
      { type: node["type"], version: NodeData.type_version(node) }
    end
    private_class_method :type_and_version
  end
end
