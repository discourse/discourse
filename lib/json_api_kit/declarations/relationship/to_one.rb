# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToOne < Relationship
        def linkage(records, filtering: {}) = Linkage::ToOne.new(records, filtering:)

        def related_document = Document::RelatedResource

        def linkage_document = Document::Relationship::ToOne
      end
    end
  end
end
