# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class ConversionError < BadRequest
        def initialize(error, location:)
          @error = error
          @location = location
          super(error.message)
        end

        delegate :title, :detail, to: :error

        def source = { pointer: location.nearest_existing.pointer }

        private

        attr_reader :error, :location
      end
    end
  end
end
