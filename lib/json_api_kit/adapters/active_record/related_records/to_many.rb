# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class RelatedRecords
        class ToMany < RelatedRecords
          def scope = association.related_scope

          private

          def sideload_scope = association.to_scoping

          def pair(records) = association.pair(records)
        end
      end
    end
  end
end
