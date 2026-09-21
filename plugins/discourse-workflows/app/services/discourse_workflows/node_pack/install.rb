# frozen_string_literal: true

module DiscourseWorkflows
  class NodePack::Install
    include Service::Base

    params do
      attribute :manifest
      attribute :approved_destinations, default: -> { [] }
      validate :approved_destinations_are_array

      def approved_destinations_are_array
        unless approved_destinations.is_a?(Array) &&
                 approved_destinations.all? { |origin| origin.is_a?(String) } &&
                 approved_destinations.uniq.length == approved_destinations.length
          errors.add(:approved_destinations, :invalid)
        end
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :parsed_manifest, :parse_manifest

    transaction do
      step :lock_pack_lifecycle
      policy :destinations_approved
      step :persist_pack
    end

    step :bump_runtime_version
    step :log_change

    private

    def parse_manifest(params:)
      parsed = NodePacks::Manifest.parse(params.manifest)
      unless parsed.valid?
        context[:error_type] = "invalid_manifest"
        context[:manifest_errors] = parsed.errors.map(&:as_json)
        return
      end
      parsed
    end

    def destinations_approved(params:, parsed_manifest:)
      required = required_destinations(parsed_manifest)
      approved = params.approved_destinations
      missing = required - approved
      unexpected = approved - required
      context[:missing] = missing
      context[:unexpected] = unexpected
      context[:error_type] = "destinations_not_approved" if missing.any? || unexpected.any?
      missing.empty? && unexpected.empty?
    end

    def required_destinations(parsed_manifest)
      manifest = parsed_manifest.manifest
      current = manifest.fetch("destinations").map { |destination| destination.fetch("origin") }
      retained =
        NodePack
          .includes(:definitions)
          .find_by(key: manifest.fetch("key"))
          &.definitions
          &.flat_map do |definition|
            Array(definition.definition.dig("_effective", "approved_origins"))
          end || []
      (current + retained).uniq
    end

    def lock_pack_lifecycle(parsed_manifest:)
      NodePacks::LifecycleLock.lock_keys!([parsed_manifest.manifest.fetch("key")])
    end

    def persist_pack(parsed_manifest:, params:, guardian:)
      manifest = parsed_manifest.manifest
      pack = NodePack.lock.find_by(key: manifest.fetch("key"))
      if pack&.removed_at
        incoming = Gem::Version.new(manifest.fetch("version"))
        installed = Gem::Version.new(pack.version)
        if incoming <= installed
          context[:installed_version] = pack.version
          conflict =
            mark_conflict(incoming == installed ? "revision_conflict" : "downgrade_not_allowed")
        else
          conflict = update_pack(pack, parsed_manifest, manifest, params, guardian)
        end
      elsif pack
        conflict = update_pack(pack, parsed_manifest, manifest, params, guardian)
      else
        pack = create_pack(parsed_manifest, manifest, params, guardian)
        context[:result] = "installed"
      end
      fail!(I18n.t("discourse_workflows.node_packs.errors.#{conflict}")) if conflict
      context[:node_pack] = pack
    rescue ActiveRecord::RecordNotUnique
      context[:error_type] = "revision_conflict"
      fail!(I18n.t("discourse_workflows.node_packs.errors.revision_conflict"))
    end

    def create_pack(parsed_manifest, manifest, params, guardian)
      NodePack
        .create!(
          key: manifest.fetch("key"),
          name: manifest.fetch("name"),
          version: manifest.fetch("version"),
          manifest:,
          manifest_sha256: NodePacks::CanonicalJson.sha256(manifest),
          approved_destinations:
            manifest.fetch("destinations").map { |destination| destination.fetch("origin") },
          installed_by_id: guardian.user.id,
          updated_by_id: guardian.user.id,
        )
        .tap do |pack|
          insert_definitions(pack, parsed_manifest.definitions, manifest.fetch("version"))
        end
    end

    def update_pack(pack, parsed_manifest, manifest, params, guardian)
      incoming = Gem::Version.new(manifest.fetch("version"))
      installed = Gem::Version.new(pack.version)
      manifest_hash = NodePacks::CanonicalJson.sha256(manifest)
      if incoming == installed
        if manifest_hash == pack.manifest_sha256
          context[:result] = "unchanged"
          return
        end
        return mark_conflict("revision_conflict")
      end
      if incoming < installed
        context[:installed_version] = pack.version
        return mark_conflict("downgrade_not_allowed")
      end

      incoming_identities = Set.new
      parsed_manifest.definitions.each do |definition|
        identifier = "action:#{manifest.fetch("key")}.#{definition.fetch("key")}"
        identity = [identifier, definition.fetch("version")]
        incoming_identities << identity
        hash = NodePacks::CanonicalJson.behavior_sha256(definition)
        record = NodePackDefinition.find_by(identifier:, version: definition.fetch("version"))
        if record && record.definition_sha256 != hash
          context[:nodes] = Array(context[:nodes]) << identifier
          return mark_conflict("definition_conflict")
        elsif record
          record.update!(retired_at: nil)
        else
          pack.definitions.create!(
            identifier:,
            version: definition.fetch("version"),
            definition:,
            definition_sha256: hash,
            introduced_in: manifest.fetch("version"),
          )
        end
      end
      pack
        .definitions
        .where.not(identifier: incoming_identities.map(&:first))
        .where(retired_at: nil)
        .update_all(retired_at: Time.current, updated_at: Time.current)
      pack.definitions.each do |record|
        next if incoming_identities.include?([record.identifier, record.version])
        record.update!(retired_at: Time.current) if record.retired_at.nil?
      end
      reactivating = pack.removed_at.present?
      pack.update!(
        {
          name: manifest.fetch("name"),
          version: manifest.fetch("version"),
          manifest:,
          manifest_sha256: manifest_hash,
          approved_destinations:
            manifest.fetch("destinations").map { |destination| destination.fetch("origin") },
          updated_by_id: guardian.user.id,
        }.merge(reactivating ? { removed_at: nil, enabled: true, palette_visible: true } : {}),
      )
      context[:result] = reactivating ? "installed" : "updated"
      nil
    end

    def insert_definitions(pack, definitions, pack_version)
      definitions.each do |definition|
        pack.definitions.create!(
          identifier: "action:#{pack.key}.#{definition.fetch("key")}",
          version: definition.fetch("version"),
          definition:,
          definition_sha256: NodePacks::CanonicalJson.behavior_sha256(definition),
          introduced_in: pack_version,
        )
      end
    end

    def mark_conflict(type)
      context[:error_type] = type
      type
    end

    def bump_runtime_version(result:)
      NodePacks::Runtime.bump! unless result == "unchanged"
    end

    def log_change(result:, node_pack:, guardian:)
      return if result == "unchanged"
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_node_pack_#{result}",
        subject: node_pack.key,
      )
    end
  end
end
