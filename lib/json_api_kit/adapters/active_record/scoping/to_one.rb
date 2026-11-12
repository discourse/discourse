# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class Scoping
        class ToOne < Scoping
          delegate :apply, :page, to: :scoping

          def initialize(scope, association:)
            @scoping = Scoping.for(scope)
            @association = association
          end

          def pairing_keys = scoping.pairing_keys | association.to_scoping.pairing_keys

          def rows(page)
            selected_records(page.rows).then do |records|
              page.rows.select { records.include?(it.record) }
            end
          end

          private

          attr_reader :scoping, :association

          def selected_records(rows)
            association.pair(rows.map(&:record)).values.filter_map(&:first).to_set
          end
        end
      end
    end
  end
end
