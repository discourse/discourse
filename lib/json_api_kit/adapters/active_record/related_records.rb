# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class RelatedRecords < Adapter::RelatedRecords
        def self.for(resource, relationship, **)
          case relationship
          when JsonApiKit::Declarations::Relationship::ToOne
            ToOne.new(resource, relationship, **)
          else
            ToMany.new(resource, relationship, **)
          end
        end

        def initialize(resource, relationship, owners:, owner_resource:)
          super(resource, owners:)
          @relationship = relationship
          @owner_resource = owner_resource
        end

        private

        attr_reader :relationship, :owner_resource

        def association
          @association ||= owner_resource.schema.association(relationship.name.to_sym, owners)
        end
      end
    end
  end
end
