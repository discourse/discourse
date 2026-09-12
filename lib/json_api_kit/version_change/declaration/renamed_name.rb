# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class RenamedName < Declaration
        def initialize(type, kinds, from:, to:, up: NO_CONVERSION, down: NO_CONVERSION)
          super(type, from:, to:, up:, down:)
          @kinds = kinds
        end

        private

        attr_reader :kinds

        def transformation(kind)
          Rename.new(from: name(kind, from), to: name(kind, to), **converters)
        end
      end
    end
  end
end
