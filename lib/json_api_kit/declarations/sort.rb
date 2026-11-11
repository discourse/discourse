# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Sort
      class << self
        def verify_direction!(direction)
          unless direction.in?(%i[asc desc])
            raise ArgumentError, "Unknown sort direction: #{direction.inspect}."
          end
        end
      end

      attr_reader :name

      def initialize(name, **options)
        @name = name.to_s
        @options = options
      end

      def key(builder:, direction:) = builder.sort_key(name, direction:, **options)

      private

      attr_reader :options
    end
  end
end
