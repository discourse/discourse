# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToMany < Relationship
        def linkage(records) = Linkage::ToMany.new(records.page(resource.page_size))
      end
    end
  end
end
