# frozen_string_literal: true

module JsonApiKit
  class Document
    class Collection < Document
      class << self
        def contract_class = Request::Contract::Collection

        def for(parameters, resource:, client:, scoped_to: nil)
          build(parameters, resource:, client:) do
            resource.all(it, guardian: client.guardian, scoped_to:)
          end
        end
      end

      private

      def primary_records = query.records

      def data
        contents.primary.map do
          ResourceObject.new(it, client:, fieldsets:, meta: page_meta(it)).to_h
        end
      end

      def page_meta(record)
        return {} unless query.item_cursors?
        { page: { cursor: record.cursor.to_s } }
      end

      def links = super.merge(PageLinks.new(urls.current, query.pages).to_h)
    end
  end
end
