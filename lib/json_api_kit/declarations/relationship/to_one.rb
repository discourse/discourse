# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToOne < Relationship
        def parameter_name = "#{name}_id"

        def parameter_type = resource.identifier_type

        def input_contract = Request::Body::Contract::Relationship::ToOne

        def linkage(records, filtering: {}) = Linkage::ToOne.new(records, filtering:)

        def related_document = Document::RelatedResource

        def linkage_document = Document::Relationship::ToOne
      end
    end
  end
end
