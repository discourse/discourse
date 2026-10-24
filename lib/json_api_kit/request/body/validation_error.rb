# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class ValidationError < JsonApiKit::Error
        delegate :pointer, to: :location, private: true

        def initialize(error, location:)
          @location = location.nearest_existing
          super(error.message)
        end

        def status = "422"

        def title = "Invalid input"

        def source = { pointer: }

        private

        attr_reader :location
      end
    end
  end
end
