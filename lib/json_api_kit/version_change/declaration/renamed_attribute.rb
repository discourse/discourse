# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class RenamedAttribute < RenamedName
        def initialize(type, from:, to:, up: NO_CONVERSION, down: NO_CONVERSION)
          super(type, DERIVED_FROM_AN_ATTRIBUTE, from:, to:, up:, down:)
        end

        private

        def verify!
          raise fault("Declare both up: and down:") if [up, down].count(NO_CONVERSION) == 1
        end
      end
    end
  end
end
