# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class RelatedRecords
        def initialize(resource, relationship, owners:, owner_resource:)
          @resource = resource
          @relationship = relationship
          @owners = owners
          @owner_resource = owner_resource
        end

        def scope = association.related_scope

        def records_by_owner(params) = pair(records(params))

        private

        attr_reader :resource, :relationship, :owners, :owner_resource

        def records(params) = resource.all(params, scoped_to: association.to_scoping).records

        def pair(records)
          association.pair(records.map(&:record)).transform_values { records.fetch_all(it) }
        end

        def association
          @association ||= owner_resource.schema.association(relationship.name.to_sym, owners)
        end
      end
    end
  end
end
