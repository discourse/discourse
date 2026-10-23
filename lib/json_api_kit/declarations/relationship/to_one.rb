# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      class ToOne < Relationship
        def linkage(records) = Linkage::ToOne.new(records)
      end
    end
  end
end
