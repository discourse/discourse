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

      def data = contents.primary.map { ResourceObject.new(it, urls:, meta: page_meta(it)).to_h }

      def page_meta(record)
        return {} unless query.item_cursors?
        { page: { cursor: record.cursor.to_s } }
      end

      def links = super.merge(PageLinks.new(urls.current, query.pages).to_h)
    end
  end
end
