# frozen_string_literal: true

module JsonApiKit
  class Document
    class Individual < Document
      class << self
        def input_class = Request::Input::Individual

        def for(id, parameters, resource:, client:)
          build(parameters, resource:, client:) { |params, instance| instance.find(id, params) }
        end

        def from(record, resource:, input:, client:)
          request = Request.new(input.to_h, guardian: client.guardian, edition: client.edition)
          assemble(
            new(Query::Result.new(resource, request, record:), client:, fieldsets: input.fieldsets),
          )
        end
      end

      def location = urls.for(query.record).to_s

      private

      def primary_records = [query.record]

      def data = ResourceObject.new(contents.primary.sole, client:, fieldsets:).to_h
    end
  end
end
