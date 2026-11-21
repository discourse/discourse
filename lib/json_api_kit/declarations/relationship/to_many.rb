# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToMany < Relationship
        def parameter_name = "#{name.singularize}_ids"

        def parameter_type =
          ActiveSupportTypeExtensions::Array.new(element_type: resource.identifier_type)

        def input_contract = Request::Body::Contract::Relationship::ToMany

        def linkage(records, filtering: {}) =
          Linkage::ToMany.new(records.page(resource.page_size), filtering:)

        def related_document = Document::Collection

        def linkage_document = Document::Relationship
      end
    end
  end
end
