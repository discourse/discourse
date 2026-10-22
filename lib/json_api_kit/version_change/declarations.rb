# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declarations
      def initialize(type)
        @type = type
        @transformations = []
        @default_sorts = []
        @removed_filters = []
        @removed_sorts = []
        @input_scope_changes = []
      end

      attr_reader :default_sorts, :removed_filters, :removed_sorts, :input_scope_changes

      def transformations
        @transformations + removed_filters.flat_map(&:transformations) +
          removed_sorts.flat_map(&:transformations)
      end

      def changed_default_sort(from:) = default_sorts << DefaultSort.new(type, from)

      def removed_filter(name, &condition)
        removed_filters << RemovedFilter.new(type, name, &condition)
      end

      # A removed input of the input scope: requests pinned before the removal may still send it,
      # and the input scope retained for them reads it.
      def removed_scope_filter(name, default:)
        removed_filters << RemovedFilter.new(type, name, default:) { |rows, _value| rows }
      end

      def changed_input_scope(&block)
        input_scope_changes << InputScopeChange.new(
          type.to_s,
          nil,
          JsonApiKit::Declarations::InputScope.new(block),
        )
      end

      def removed_sort(name, **options)
        removed_sorts << RemovedSort.new(type, name, **options)
      end

      def renamed_attribute(**) = declare(Declaration::RenamedAttribute.new(type, **))

      def merged_attributes(**) = declare(Declaration::MergedAttributes.new(type, **))

      def split_attribute(**) = declare(Declaration::SplitAttribute.new(type, **))

      def renamed_sort(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Sort], from:, to:))
      end

      def renamed_filter(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Filter], from:, to:))
      end

      def collection(name, &declarations)
        CollectionDeclarations
          .new(type, name)
          .tap { it.instance_eval(&declarations) }
          .then do
            @transformations.concat(it.renames)
            removed_filters.concat(it.removed_filters)
            input_scope_changes.concat(it.input_scope_changes)
          end
      end

      def renamed_relationship(from:, to:)
        declare(Declaration::RenamedName.new(type, [Name::Relationship, Name::Field], from:, to:))
      end

      private

      attr_reader :type

      def declare(declaration) = @transformations.concat(declaration.transformations)
    end
  end
end
