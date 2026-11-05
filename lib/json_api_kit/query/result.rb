# frozen_string_literal: true

module JsonApiKit
  class Query
    class Result < Query
      Row = Data.define(:record)

      def initialize(resource, request, records:)
        super(resource, request)
        @rows = records.map { Row.new(it) }
      end

      attr_reader :rows

      def record = records.sole

      def pages = {}

      def item_cursors? = false
    end
  end
end
