# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class RelatedRecords
        class ToOne < RelatedRecords
          def scope = Scoping::ToOne.new(association.related_scope, association:)

          private

          def sideload_scope = Scoping::ToOne.new(association.to_scoping, association:)

          def pair(records) = association.pair(records).transform_values { it.first(1) }
        end
      end
    end
  end
end
