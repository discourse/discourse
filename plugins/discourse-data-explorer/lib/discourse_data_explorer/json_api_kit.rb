# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The spike API's v-day zero (docs/versioning-design.md, §1).
    INITIAL_API_VERSION = "2026-05-01"

    # Extensions that ship atomically with core (one repo, one deploy) ride
    # the core timeline: their changes join the base snap set and cannot be
    # overridden. Membership is GRANTED here — reviewed data in core's
    # codebase, following the `config/official_plugins.json` precedent — and
    # plugins have no syntax to claim it. Fails closed: a missing entry means an
    # own timeline (override-gated), never a stranded pin. A repo ⟺ list CI
    # consistency check is the real-phase companion (a stale entry after a
    # plugin leaves the repo is the dangerous drift). Empty in the spike.
    CORE_PLUGINS = [].freeze

    class << self
      # The API's version registry — every VersionChange is registered here.
      # Memoized for the process lifetime; in dev a code reload can leave stale
      # change classes behind (restart to refresh). Spike trade-off.
      def api_versions
        @api_versions ||=
          VersionRegistry
            .new(initial_version: INITIAL_API_VERSION)
            .tap do |registry|
              registry.register(VersionChanges::RenameQueriesSqlToQuery)
              registry.register(VersionChanges::ChangeUsersUsernameToList)
              registry.register(VersionChanges::RenameQueriesLastRunAtToRanAt)
              registry.register(VersionChanges::RenameQueriesSearchFilterToQ)
              registry.register(VersionChanges::RenameQueriesUsernameSortToUserUsername)
            end
      end

      # ── Extensions (docs/plugins-design.md) ──
      # A foreign owner registers everything in one block; the whole contribution
      # is validated before anything is applied, so failure leaves no partial state.
      # In real plugins this is the target of the plugin.rb `jsonapi` keyword.

      def register_extension(namespace:, &block)
        extension = Extension.new(namespace:)
        extension.instance_eval(&block)
        validate_extension!(extension)
        apply_extension(extension)
        extensions[extension.namespace] = extension
      end

      def unregister_extension(namespace)
        extension = extensions.delete(namespace.to_s)
        return if !extension

        extension.attached_types.each do |type|
          serializer_for(type).relationships_to_serialize&.delete(extension.namespace.to_sym)
        end
        extension.version_changes.each { api_versions.unregister(it) }
      end

      def extensions = @extensions ||= {}

      def extension_filters_for(type)
        extensions
          .values
          .reduce({}) { |merged, extension| merged.merge(extension.filters_for(type)) }
      end

      def extension_namespaces_for(type)
        extensions.values.filter_map do |extension|
          extension.namespace if extension.attached_types.include?(type.to_s)
        end
      end

      def core_plugin?(namespace) = CORE_PLUGINS.include?(namespace.to_s)

      # Spike stand-in for a real resource registry — the resource-level home is a
      # design follow-up (docs/versioning-design.md §3).
      def serializer_for(type)
        @resource_serializers ||=
          [QuerySerializer, UserSerializer, GroupSerializer].to_h { [it.record_type.to_s, it] }
        @resource_serializers[type.to_s]
      end

      private

      def validate_extension!(extension)
        if extensions.key?(extension.namespace)
          raise Extension::NamespaceError,
                "The `#{extension.namespace}` namespace is already registered"
        end

        extension.attached_types.each do |type|
          serializer = serializer_for(type)
          raise Extension::Error, "Unknown resource type `#{type}`" if !serializer

          if member_names(serializer).include?(extension.namespace)
            raise Extension::NamespaceError,
                  "The `#{extension.namespace}` namespace collides with a member name on `#{type}`"
          end
        end

        foreign_types =
          extension.version_changes.flat_map(&:resource_types).map(&:to_s) - extension.owned_types
        if foreign_types.any?
          raise Extension::OwnershipError,
                "Version changes may only target owned types (foreign: #{foreign_types.join(", ")})"
        end
      end

      def apply_extension(extension)
        extension.relationships.each do |type, relationship|
          related = relationship[:block]
          serializer_for(type).has_one(
            extension.namespace.to_sym,
            serializer: relationship[:serializer],
            lazy_load_data: true,
          ) { |record, _params| related.call(record) }
        end
        # One union registry per site: the extension's changes join the timeline
        # (they only ever transform its own types — enforced above) and leave it
        # with the extension. A core plugin's changes are core-owned — they enter
        # the base snap set; an independent extension's changes carry its
        # namespace and are reached through overrides.
        owner = core_plugin?(extension.namespace) ? nil : extension.namespace
        extension.version_changes.each { api_versions.register(it, owner:) }
      end

      def member_names(serializer)
        attributes = serializer.attributes_to_serialize&.keys || []
        relationships = serializer.relationships_to_serialize&.keys || []
        (attributes + relationships).map(&:to_s)
      end
    end
  end
end
