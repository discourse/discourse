# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
      class Query < JsonApiKit::Query
        def initialize(resource, request, scoped_to: nil)
          super(resource, request)
          @scoped_to = scoped_to
        end

        def rows = @rows ||= scoping.rows(page)

        private

        attr_reader :scoped_to

        delegate :adapter, :schema, to: :resource, private: true

        def page
          @page ||=
            scoping.page(adapter.requested_page(request)).paginate(scope, order:, limits:, anchors:)
        end

        def limits = resource.page_limits

        def anchors = resource.anchors(guardian)

        def scope = columns.apply(scoping.apply(filtered_scope))

        def scoping = @scoping ||= Scoping.for(scoped_to)

        def columns
          Columns.for_fields(fields, schema:).with(
            *order.columns,
            *owner_keys,
            *scoping.pairing_keys,
            schema.primary_key,
          )
        end

        def owner_keys
          relationships.flat_map do |relationship|
            relationship.resource.adapter.required_owner_fields(
              relationship.name,
              owner_resource: resource,
            )
          end
        end

        def filtered_scope = resource.apply_filters(available_scope, request.filtering)

        def available_scope = resource.scope_for(guardian)

        def order = @order ||= resource.order(request.ordering)
      end
    end
  end
end
