# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class RenamedAttribute < Declaration
        NO_CONVERSION = ->(value) { value }

        def initialize(type, from:, to:, up: NO_CONVERSION, down: NO_CONVERSION)
          super
        end

        private

        def verify!
          raise fault("Declare both up: and down:") if [up, down].count(NO_CONVERSION) == 1
        end

        def transformation(kind)
          Rename.new(from: name(kind, from), to: name(kind, to), **converters)
        end
      end
    end
  end
end
