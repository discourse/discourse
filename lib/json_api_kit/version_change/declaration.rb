# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class Fault < ArgumentError
        def initialize(message, from:, to:)
          super("#{message}, to change #{Array(from).join(", ")} into #{to}.")
        end
      end

      DERIVED_FROM_AN_ATTRIBUTE = [Name::Field, Name::Sort, Name::Anchor].freeze

      def initialize(type, from:, to:, up:, down:)
        @type = type.to_s
        @from = from
        @to = to
        @up = up
        @down = down
      end

      def transformations
        verify!
        DERIVED_FROM_AN_ATTRIBUTE.map { transformation(it) }
      end

      private

      attr_reader :type, :from, :to, :up, :down

      def verify! = nil

      def transformation(_kind)
        raise NotImplementedError, "#{self.class} must implement transformation(kind)"
      end

      def converters
        @converters ||= {
          up: Converter.new(:up, up, names(Name::Field, from)),
          down: Converter.new(:down, down, names(Name::Field, to)),
        }
      rescue ArgumentError => error
        raise fault(error.message)
      end

      def names(kind, values) = Array(values).map { name(kind, it) }

      def name(kind, value) = kind.new(value: value.to_s, type:)

      def fault(message) = Fault.new(message, from:, to:)
    end
  end
end
