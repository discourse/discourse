# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class SplitAttribute < Declaration
        def initialize(type, from:, to:, up:, down:)
          super(type, from:, to: Array(to), up:, down:)
        end

        private

        def kinds = [Name::Field]

        def verify!
          raise fault("Declare one source name") if from.is_a?(Array) || from.nil?
          raise fault("Declare at least two names") unless to.many?
          raise fault("Declare distinct names") unless to.map(&:to_s).uniq.size == to.size
        end

        def transformation(kind)
          Split.new(from: name(kind, from), to: names(kind, to), **converters)
        end
      end
    end
  end
end
