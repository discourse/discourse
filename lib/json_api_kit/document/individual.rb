# frozen_string_literal: true

module JsonApiKit
  class Document
    class Individual < Document
      class << self
        def contract_class = Request::Contract::Individual

        def for(id, parameters, resource:, client:)
          build(parameters, resource:, client:) { resource.find(id, it, guardian: client.guardian) }
        end
      end

      private

      def primary_records = [query.record]

      def data = ResourceObject.new(contents.primary.sole, client:, fieldsets:).to_h
    end
  end
end
