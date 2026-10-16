# frozen_string_literal: true

module JsonApiKit
  class Query
    class Result < Individual
      Row = Data.define(:record)

      def initialize(resource, request, record:)
        super(resource, request)
        @rows = [Row.new(record)]
      end

      attr_reader :rows
    end
  end
end
