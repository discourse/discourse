# frozen_string_literal: true

module JsonApiKit
  class Document
    class Collection < Document
      class << self
        def contract_class = Request::Contract::Collection

        def for(parameters, resource:, guardian:, urls:, scoped_to: nil)
          build(parameters, resource:, urls:) { resource.all(it, guardian:, scoped_to:) }
        end
      end

      private

      def primary_records = query.records

      def data
        contents.primary.map do |record|
          ResourceObject.new(record, urls:, meta: { page: { cursor: record.cursor.to_s } }).to_h
        end
      end

      def links = super.merge(PageLinks.new(urls.current, query.pages).to_h)
    end
  end
end
