# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class ValidationError < JsonApiKit::Error
        def initialize(error, location:)
          @location = location
          super(error.message)
        end

        def status = "422"

        def title = "Invalid input"

        def source = { pointer: location.nearest_existing.pointer }

        private

        attr_reader :location
      end
    end
  end
end
