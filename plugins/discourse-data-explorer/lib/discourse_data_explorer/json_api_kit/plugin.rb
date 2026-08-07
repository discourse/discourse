# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # One foreign owner's contribution to the API — a namespace plus what it
    # attaches to other owners' types (relationships, namespaced filters) and the
    # version changes for its own types. Built by the `JsonApiKit.register_plugin`
    # block, then validated and applied as a unit. See docs/plugins-design.md (B/D).
    class Plugin
      Error = Class.new(StandardError)
      NamespaceError = Class.new(Error)
      OwnershipError = Class.new(Error)

      attr_reader :namespace, :relationships, :version_changes

      def initialize(namespace:)
        @namespace = namespace.to_s
        @relationships = {}
        @filters = {}
        @version_changes = []
      end

      # `resource:` must be a Kit resource class (validated at registration):
      # plugin types are documented from the same declarations as core ones,
      # and a plain serializer has none to offer.
      def register_relationship(type, resource:, description: nil, &block)
        @relationships[type.to_s] = { resource:, description:, block: }
      end

      # Keys are declared local and wired prefixed — the plugin never writes
      # (and cannot write) a foreign prefix. Same typed, described declaration
      # as the resource `filter` keyword; the docs derive from it.
      def register_filter(type, key, value_type, description:, &block)
        ActiveModel::Type.lookup(value_type)
        (@filters[type.to_s] ||= {})["#{namespace}.#{key}"] = {
          type: value_type,
          description:,
          block:,
        }
      end

      def register_version_change(change)
        @version_changes << change
      end

      def filters_for(type) = @filters.fetch(type.to_s, {})

      # The types this plugin introduces (through its relationship resources) —
      # the only types its version changes may target.
      def owned_types = relationships.values.map { it[:resource].record_type.to_s }

      def attached_types = relationships.keys

      # The D ownership amendment (docs/plugins-design.md): query-surface vocabulary
      # is owned by namespace. A change declares `renamed_filter` in its OWN type's
      # vocabulary; this projects it onto an attached surface with both sides
      # prefixed — a foreign (unprefixed) rename is inexpressible.
      def filter_renames_on(surface_type, change:)
        return {} if !attached_types.include?(surface_type.to_s)
        return {} if !version_changes.include?(change)

        owned_types.reduce({}) do |merged, type|
          merged.merge(
            change
              .filter_renames_for(type)
              .to_h { |from, to| [:"#{namespace}.#{from}", :"#{namespace}.#{to}"] },
          )
        end
      end
    end
  end
end
