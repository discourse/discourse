# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    # The changes to one of a resource's named collections. Only filters belong to a collection;
    # sorts, fields and the type belong to the whole resource, so declaring them here fails.
    class CollectionDeclarations
      def initialize(type, collection)
        @type = type
        @collection = collection.to_s
        @renames = []
        @removed_filters = []
        @input_scope_changes = []
      end

      attr_reader :renames, :removed_filters, :input_scope_changes

      def removed_filter(name, &condition)
        removed_filters << RemovedFilter.new(type, name, collection:, &condition)
      end

      def removed_scope_filter(name, default:)
        removed_filters << RemovedFilter.new(type, name, collection:, default:) do |rows, _value|
          rows
        end
      end

      def changed_input_scope(&block)
        input_scope_changes << InputScopeChange.new(
          type.to_s,
          collection,
          JsonApiKit::Declarations::InputScope.new(block),
        )
      end

      def renamed_filter(from:, to:)
        renames.concat(
          Declaration::RenamedName.new(
            type,
            [Name::Filter],
            from:,
            to:,
            collection:,
          ).transformations,
        )
      end

      private

      attr_reader :type, :collection
    end
  end
end
