# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class Declaration
      class Fault < ArgumentError
        def initialize(message, from:, to:)
          super("#{message}, to change #{Array(from).join(", ")} into #{Array(to).join(", ")}.")
        end
      end

      DERIVED_FROM_AN_ATTRIBUTE = [Name::Field, Name::Sort, Name::Anchor].freeze
      NO_CONVERSION = ->(value) { value }

      def initialize(type, from:, to:, up:, down:)
        @type = type.to_s
        @from = from
        @to = to
        @up = up
        @down = down
      end

      def transformations
        verify!
        kinds.map { transformation(it) }
      end

      private

      attr_reader :type, :from, :to, :up, :down

      def verify! = nil

      def kinds = raise NotImplementedError, "#{self.class} must implement kinds"

      def transformation(_kind)
        raise NotImplementedError, "#{self.class} must implement transformation(kind)"
      end

      def converters
        @converters ||= {
          up: Converter.for(:up, up, from: names(Name::Field, from), to: names(Name::Field, to)),
          down:
            Converter.for(:down, down, from: names(Name::Field, to), to: names(Name::Field, from)),
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
