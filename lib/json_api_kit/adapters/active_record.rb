# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      def all(request, scoped_to: nil) = Query::Collection.new(resource, request, scoped_to:)

      def find(request) = Query::Individual.new(resource, request)

      def collection?(value) = super || value.is_a?(::ActiveRecord::Relation)

      def scope_for(guardian)
        return resource.scope_definition.call(guardian) if resource.scope_definition
        resource.model.all
      end

      def record_for(id)
        scope_for(resource.guardian).find_by(schema.primary_key => id) or raise NotFound
      end

      def filter(scope, name, value) = scope.where(name => value)

      def anchors(guardian)
        Declarations::Anchors.new(resource.anchor_declarations, guardian:)
      end

      def requested_page(request) = Page::Requested.from(request, adapter: self)

      def related_records(relationship, owners:, owner_resource:)
        RelatedRecords.for(resource, relationship, owners:, owner_resource:)
      end

      def related_scope(name, owner_id:)
        schema.association(name.to_sym, [record_for(owner_id)]).related_scope
      end
    end
  end
end
