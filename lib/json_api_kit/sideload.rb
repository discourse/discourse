# frozen_string_literal: true

module JsonApiKit
  class Sideload
    delegate :name, to: :relationship

    def initialize(relationship, paths:, rows:, request:, owner_resource:)
      @relationship = relationship
      @paths = paths
      @rows = rows
      @request = request
      @owner_resource = owner_resource
    end

    def linkage_for(row) = relationship.linkage(related_to(row))

    private

    attr_reader :relationship, :paths, :rows, :request, :owner_resource

    def related_to(row) = related_by_row.fetch(row.record) { Records.new([]) }

    def related_by_row
      @related_by_row ||= related_records.records_by_owner(request.for_sideload(paths))
    end

    def owner_records = rows.map(&:record)

    def related_records
      resource.related_records(relationship, owners: owner_records, owner_resource:)
    end

    def resource
      @resource ||= relationship.resource.new(guardian: request.guardian, edition: request.edition)
    end
  end
end
