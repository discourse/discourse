# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class Error < BadRequest
        def initialize(error, title:, detail: nil, source: nil, type: nil, meta: nil)
          @error = error
          @title = title
          @detail = detail
          @source = source
          @type = type
          @meta = meta
          super()
        end

        attr_reader :title, :type

        delegate :options, :base, to: :error

        def detail = @detail&.call(self) || error.message

        def source = { parameter: @source&.call(self) || parameter }

        def meta = @meta&.call(self) || {}

        def parameter
          name, *nested = error.attribute.to_s.split(".")
          nested.reduce(name) { |named, part| "#{named}[#{part}]" }
        end

        private

        attr_reader :error
      end
    end
  end
end
