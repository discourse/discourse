# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class MergedAttributes < Declaration
        def initialize(type, from:, to:, up:, down:)
          super(type, from: Array(from), to:, up:, down:)
        end

        private

        def verify!
          raise fault("Declare at least two names") unless from.many?
        end

        def transformation(kind)
          Merge.new(from: names(kind, from), to: name(kind, to), **converters)
        end
      end
    end
  end
end
