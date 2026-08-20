# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The spike API's v-day zero (docs/versioning-design.md, §1).
    INITIAL_API_VERSION = "2026-05-01"

    # Plugins that ship atomically with core (one repo, one deploy) ride
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

      # ── Plugins (docs/plugins-design.md) ──
      # A foreign owner registers everything in one block; the whole contribution
      # is validated before anything is applied, so failure leaves no partial state.
      # In real plugins this is the target of the plugin.rb `jsonapi` keyword.

      def register_plugin(namespace:, &block)
        plugin = Plugin.new(namespace:)
        plugin.instance_eval(&block)
        validate_plugin!(plugin)
        apply_plugin(plugin)
        plugins[plugin.namespace] = plugin
      end

      def unregister_plugin(namespace)
        plugin = plugins.delete(namespace.to_s)
        return if !plugin

        plugin.attached_types.each do |type|
          target = serializer_for(type)
          target.relationships_to_serialize&.delete(plugin.namespace.to_sym)
          target.relationship_definitions.delete(plugin.namespace.to_sym)
        end
        plugin.version_changes.each { api_versions.unregister(it) }
      end

      def plugins = @plugins ||= {}

      def plugin_filters_for(type)
        plugins.values.reduce({}) { |merged, plugin| merged.merge(plugin.filters_for(type)) }
      end

      def plugin_namespaces_for(type)
        plugins.values.filter_map do |plugin|
          plugin.namespace if plugin.attached_types.include?(type.to_s)
        end
      end

      def core_plugin?(namespace) = CORE_PLUGINS.include?(namespace.to_s)

      # Captured live exchanges (see open_api_examples_spec.rb); absent until
      # the first capture run.
      def openapi_examples
        path = File.expand_path("../../openapi-examples.json", __dir__)
        File.exist?(path) ? JSON.parse(File.read(path)) : {}
      end

      # The OpenAPI document (docs/api-docs-generation.md) — recomputed per
      # call, so it reflects live registry/plugin state. `scope: :site`
      # (default) composes everything registered here — what this installation
      # serves; `scope: :core` is the global core document (§8). The explicit
      # endpoint map is the spike seam (see the generator's generalization path).
      def openapi_document(scope: :site) = openapi_generator(scope:).document

      # One document per registered version (newest first) — old-version
      # documents legitimately change over time: every new change deepens their
      # gap, so they regenerate alongside the latest one.
      def openapi_versions = api_versions.versions.map(&:to_s).reverse

      def openapi_document_at(version, scope: :site)
        openapi_generator(scope:).document_at(version)
      end

      # One plugin's own document — the ownership projection (§8). `at:` pins it
      # to one of the plugin's own versions.
      def openapi_document_for(namespace, at: nil)
        openapi_generator.document_for(namespace, at:)
      end

      # The plugin's own snap dates (newest first) — its docs-page version picker.
      def openapi_plugin_versions(namespace)
        api_versions.versions_for(namespace).map(&:to_s).reverse
      end

      # Spike stand-in for a real resource registry — the resource-level home is a
      # design follow-up (docs/versioning-design.md §3).
      def serializer_for(type)
        @resource_serializers ||=
          [QueryResource, UserResource, GroupResource].to_h { [it.record_type.to_s, it] }
        @resource_serializers[type.to_s]
      end

      private

      def openapi_generator(scope: :site)
        OpenApiGenerator.new(
          intro: File.read(File.expand_path("../../docs/api-intro.md", __dir__)),
          examples: openapi_examples,
          scope:,
        )
      end

      def validate_plugin!(plugin)
        if plugins.key?(plugin.namespace)
          raise Plugin::NamespaceError, "The `#{plugin.namespace}` namespace is already registered"
        end

        plugin.relationships.each_value do |relationship|
          resource = relationship[:resource]
          next if resource.is_a?(Class) && resource < ResourceBase
          raise Plugin::Error,
                "Plugin resources must be Kit resource classes (got `#{resource.inspect}`)"
        end

        plugin.attached_types.each do |type|
          serializer = serializer_for(type)
          raise Plugin::Error, "Unknown resource type `#{type}`" if !serializer

          if member_names(serializer).include?(plugin.namespace)
            raise Plugin::NamespaceError,
                  "The `#{plugin.namespace}` namespace collides with a member name on `#{type}`"
          end
        end

        foreign_types =
          plugin.version_changes.flat_map(&:resource_types).map(&:to_s) - plugin.owned_types
        if foreign_types.any?
          raise Plugin::OwnershipError,
                "Version changes may only target owned types (foreign: #{foreign_types.join(", ")})"
        end
      end

      def apply_plugin(plugin)
        plugin.relationships.each do |type, relationship|
          related = relationship[:block]
          serializer_for(type).has_one(
            plugin.namespace.to_sym,
            resource: relationship[:resource],
            description: relationship[:description],
          ) { |record, _params| related.call(record) }
        end
        # One union registry per site: the plugin's changes join the timeline
        # (they only ever transform its own types — enforced above) and leave it
        # with the plugin. A core plugin's changes are core-owned — they enter
        # the base snap set; an independent plugin's changes carry its
        # namespace and are reached through overrides.
        owner = core_plugin?(plugin.namespace) ? nil : plugin.namespace
        plugin.version_changes.each { api_versions.register(it, owner:) }
      end

      def member_names(serializer)
        attributes = serializer.attributes_to_serialize&.keys || []
        relationships = serializer.relationships_to_serialize&.keys || []
        (attributes + relationships).map(&:to_s)
      end
    end
  end
end
