# frozen_string_literal: true

module JsonApiKit
  class Query
    def initialize(resource, request, scoped_to: nil)
      @resource = resource
      @request = request
      @scoped_to = scoped_to
    end

    def rows = page.rows

    def records
      @records ||=
        Records.new(
          rows.map do
            Record.new(it, fields, type: resource.type, relationships: sideloads.linkage_for(it))
          end,
        )
    end

    def included = Included.for(records)

    delegate :item_cursors?, to: :request

    private

    attr_reader :resource, :request, :scoped_to

    delegate :guardian, to: :request, private: true

    def page = @page ||= scoping.page(request.page).paginate(scope, order:, limits:, anchors:)

    def limits = resource.page_limits

    def anchors = resource.anchors(guardian)

    def scope = columns.apply(scoping.apply(filtered_scope))

    def scoping = @scoping ||= Scoping.for(scoped_to)

    def columns
      fields.columns.with(*order.columns, *owner_keys, *scoping.pairing_keys, primary_key)
    end

    def owner_keys = relationships.map { schema.owner_key(it.name.to_sym) }

    def primary_key = schema.primary_key

    def schema = @schema ||= resource.schema

    def fields = @fields ||= resource.fields(request.fields[resource.type])

    def sideloads
      @sideloads ||= Sideloads.for(relationships, paths:, rows:, request:, schema:)
    end

    def relationships = @relationships ||= fields.relationships.pick(paths.relationship_names)

    def paths = @paths ||= resource.allow(request.including)

    def filtered_scope = resource.apply_filters(available_scope, request.filtering)

    def available_scope = request.scope(from: resource.scope_for(guardian))

    def order = @order ||= resource.order(request.ordering)
  end
end
