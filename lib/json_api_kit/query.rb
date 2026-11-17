# frozen_string_literal: true

module JsonApiKit
  class Query
    def initialize(resource, request)
      @resource = resource
      @request = request
    end

    def records
      @records ||=
        Records.new(
          rows.map do |row|
            Record.new(row, fields, type:, namespace:, relationships: sideloads.linkage_for(row))
          end,
        )
    end

    def included = Included.for(records)

    delegate :item_cursors?, to: :request

    private

    attr_reader :resource, :request

    delegate :guardian, to: :request, private: true
    delegate :type, :namespace, to: :resource, private: true

    def fields = @fields ||= resource.fields(request.fields[type], guardian:)

    def sideloads
      @sideloads ||= Sideloads.for(relationships, paths:, rows:, request:, resource:)
    end

    def relationships = @relationships ||= fields.relationships.pick(paths.relationship_names)

    def paths = @paths ||= resource.allow(request.including)
  end
end
