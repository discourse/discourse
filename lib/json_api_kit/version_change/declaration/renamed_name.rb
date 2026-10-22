# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class RenamedName < Declaration
        def initialize(
          type,
          kinds,
          from:,
          to:,
          up: NO_CONVERSION,
          down: NO_CONVERSION,
          collection: nil
        )
          super(type, from:, to:, up:, down:)
          @kinds = kinds
          @collection = collection
        end

        private

        attr_reader :kinds, :collection

        def transformation(kind)
          Rename.new(from: scoped_name(kind, from), to: scoped_name(kind, to), **converters)
        end

        # Only the kinds a collection can declare carry its name.
        def scoped_name(kind, value)
          return name(kind, value) if kind.members.exclude?(:collection)
          kind.new(value: value.to_s, type:, collection:)
        end
      end
    end
  end
end
