# frozen_string_literal: true

module JsonApiKit
  class Document
    class Individual < Document
      class << self
        def contract_class = Request::Contract::Individual

        def for(id, parameters, resource:, guardian:, urls:, glossary:)
          build(parameters, resource:, urls:, glossary:) { resource.find(id, it, guardian:) }
        end
      end

      private

      def primary_records = [query.record]

      def data = ResourceObject.new(contents.primary.sole, urls:, glossary:).to_h
    end
  end
end
