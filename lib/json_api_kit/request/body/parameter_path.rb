# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class ParameterPath
        def self.for(parameter)
          case parameter
          when self
            parameter
          else
            new(parameter)
          end
        end

        def initialize(parameter)
          @segments = parameter.to_s.split(/[.\[\]]/, 3)
        end

        def name = segments.first.to_s.to_sym

        def index = Integer(segments.second, 10, exception: false)

        def base? = segments == ["base"]

        private

        attr_reader :segments
      end
    end
  end
end
