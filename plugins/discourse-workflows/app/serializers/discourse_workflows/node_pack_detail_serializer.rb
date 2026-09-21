# frozen_string_literal: true

module DiscourseWorkflows
  class NodePackDetailSerializer < NodePackSerializer
    attributes :homepage, :credentials, :nodes, :used_by, :removal

    def homepage
      object.manifest["homepage"]
    end

    def credentials
      object.manifest.fetch("credentials", [])
    end

    def nodes
      definitions
        .sort_by { |definition| [definition.identifier, Gem::Version.new(definition.version)] }
        .map do |record|
          definition = record.definition
          {
            identifier: record.identifier,
            key: record.identifier.split(".", 2).last,
            version: record.version,
            label: definition["label"],
            subtitle: definition["subtitle"],
            description: definition["description"],
            docs_url: definition["docs_url"],
            icon: definition["icon"],
            color: definition["color"],
            credential: definition["credential"],
            retired: record.retired_at.present?,
            introduced_in: record.introduced_in,
            request: definition.fetch("request").slice("method", "url"),
            used_by_count: node_usage_counts.fetch(record.identifier, 0),
          }.compact
        end
    end

    def used_by
      @options[:usage] || NodePacks::UsageQuery.new(definitions.map(&:identifier)).workflows
    end

    def removal
      { blocked: used_by.any? || active_executions.positive?, active_executions: }
    end

    private

    def active_executions
      @options[:active_executions] ||
        NodePacks::UsageQuery.new(definitions.map(&:identifier)).active_executions
    end

    def node_usage_counts
      @options[:node_usage_counts] ||
        NodePacks::UsageQuery.new(definitions.map(&:identifier)).node_usage_counts
    end
  end
end
