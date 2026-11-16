# frozen_string_literal: true

module JsonApiKit
  class Document
    class Collection < Document
      class << self
        def input_class = Request::Input::Collection

        def for(parameters, resource:, client:, scoped_to: nil)
          build(parameters, resource:, client:) do |params, instance|
            instance.all(params, scoped_to:)
          end
        end

        def from(...) = from_records(...)
      end

      private

      def primary_records = query.records

      def data
        contents.primary.map { representation(it, meta: page_meta(it)).to_h }
      end

      def representation(record, meta:)
        ResourceObject.new(record, client:, fieldsets:, meta:)
      end

      def page_meta(record)
        return {} unless query.item_cursors?
        { page: { cursor: record.cursor.to_s } }
      end

      def links = super.merge(PageLinks.new(urls.current, query.pages).to_h)
    end
  end
end
