# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToMany < Relationship
        def linkage(records, filtering: {}) =
          Linkage::ToMany.new(records.page(resource.page_size), filtering:)

        def related_document = Document::Collection

        def linkage_document = Document::Relationship
      end
    end
  end
end
