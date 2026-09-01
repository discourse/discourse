# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToMany < Relationship
        def scoping(association) = association.to_scoping

        def linkage(records) = Linkage::ToMany.new(records.page(resource.page_size))
      end
    end
  end
end
