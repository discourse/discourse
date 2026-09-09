# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToOne < Relationship
        def scoping(association) = association.to_scoping

        def linkage(records) = Linkage::ToOne.new(records)
      end
    end
  end
end
