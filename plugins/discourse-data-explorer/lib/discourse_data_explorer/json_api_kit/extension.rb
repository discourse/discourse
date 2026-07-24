# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # One foreign owner's contribution to the API — a namespace plus what it
    # attaches to other owners' types (relationships, namespaced filters) and the
    # version changes for its own types. Built by the `JsonApiKit.register_extension`
    # block, then validated and applied as a unit. See docs/plugins-design.md (B/D).
    class Extension
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

      def register_relationship(type, serializer:, &block)
        @relationships[type.to_s] = { serializer:, block: }
      end

      # Keys are declared local and wired prefixed — the extension never writes
      # (and cannot write) a foreign prefix.
      def register_filter(type, key, &block)
        (@filters[type.to_s] ||= {})["#{namespace}.#{key}"] = block
      end

      def register_version_change(change)
        @version_changes << change
      end

      def filters_for(type) = @filters.fetch(type.to_s, {})

      # The types this extension introduces (through its relationship serializers) —
      # the only types its version changes may target.
      def owned_types = relationships.values.map { it[:serializer].record_type.to_s }

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
