# frozen_string_literal: true

module DiscourseWorkflows
  class NodePack::Preview
    include Service::Base

    params do
      attribute :manifest
      validate :manifest_present_and_bounded

      def manifest_present_and_bounded
        errors.add(:manifest, :blank) if manifest.blank?
        if manifest.is_a?(String) && manifest.bytesize > NodePacks::Limits::MAX_MANIFEST_BYTES
          errors.add(:manifest, :too_long)
        end
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :parsed_manifest, :parse_manifest
    model :preview, :build_preview

    private

    def parse_manifest(params:)
      result = NodePacks::Manifest.parse(params.manifest)
      if !result.valid?
        context[:manifest_errors] = result.errors.map(&:as_json)
        return
      end
      result
    end

    def build_preview(parsed_manifest:)
      manifest = parsed_manifest.manifest
      existing = NodePack.includes(:definitions).find_by(key: manifest["key"])
      records =
        existing&.definitions&.index_by { |record| [record.identifier, record.version] } || {}
      seen = Set.new
      nodes =
        parsed_manifest.definitions.map do |definition|
          identifier = "action:#{manifest["key"]}.#{definition["key"]}"
          identity = [identifier, definition["version"]]
          seen << identity
          record = records[identity]
          prior_versions =
            existing&.definitions&.select do |definition_record|
              definition_record.identifier == identifier
            end || []
          hash = NodePacks::CanonicalJson.behavior_sha256(definition)
          change =
            if record.nil?
              prior_versions.any? ? "changed" : "new"
            elsif record.definition_sha256 == hash
              "unchanged"
            else
              "conflict"
            end
          preview_node(definition, identifier, change, record&.introduced_in || manifest["version"])
        end
      existing
        &.definitions
        &.select do |record|
          record.retired_at.nil? && seen.exclude?([record.identifier, record.version])
        end
        &.each do |record|
          nodes << preview_node(
            record.definition,
            record.identifier,
            "dropped",
            record.introduced_in,
            retired: true,
          )
        end
      change = preview_change(existing, manifest, nodes)
      {
        manifest:
          manifest.slice("key", "name", "version", "description", "homepage", "icon", "color"),
        destinations: effective_destinations(existing, manifest),
        credentials: manifest.fetch("credentials"),
        nodes:,
        installed:
          existing && { id: existing.id, version: existing.version, enabled: existing.enabled },
        change:,
        previously_approved_destinations: existing&.approved_destinations || [],
        warnings:
          nodes
            .select { |node| node[:change] == "dropped" }
            .map do |node|
              I18n.t(
                "discourse_workflows.node_packs.dropped_warning",
                identifier: node[:identifier],
              )
            end,
      }
    end

    def preview_change(existing, manifest, nodes)
      return "install" unless existing
      comparison = Gem::Version.new(manifest["version"]) <=> Gem::Version.new(existing.version)
      return "downgrade" if comparison.negative?
      if comparison.zero? &&
           (
             existing.removed_at? ||
               existing.manifest_sha256 != NodePacks::CanonicalJson.sha256(manifest)
           )
        return "revision_conflict"
      end
      return "definition_conflict" if nodes.any? { |node| node[:change] == "conflict" }
      return "unchanged" if comparison.zero?
      existing.removed_at? ? "install" : "update"
    end

    def effective_destinations(existing, manifest)
      current = manifest.fetch("destinations").map { |destination| destination.fetch("origin") }
      retired =
        existing
          &.definitions
          &.filter_map { |record| record.definition.dig("_effective", "approved_origins") }
          &.flatten || []
      (current + retired).uniq
    end

    def preview_node(definition, identifier, change, introduced_in, retired: false)
      {
        identifier:,
        key: definition["key"] || identifier.split(".", 2).last,
        version: definition["version"],
        label: definition["label"],
        subtitle: definition["subtitle"],
        description: definition["description"],
        docs_url: definition["docs_url"],
        icon: definition["icon"],
        color: definition["color"],
        credential: definition["credential"],
        retired:,
        introduced_in:,
        request: definition.fetch("request").slice("method", "url"),
        used_by_count: 0,
        change:,
      }.compact
    end
  end
end
