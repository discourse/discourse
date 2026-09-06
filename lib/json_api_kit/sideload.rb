# frozen_string_literal: true

module JsonApiKit
  class Sideload
    delegate :name, to: :relationship

    def initialize(relationship, paths:, rows:, request:, schema:)
      @relationship = relationship
      @paths = paths
      @rows = rows
      @request = request
      @schema = schema
    end

    def linkage_for(row) = relationship.linkage(related_to(row))

    private

    attr_reader :relationship, :paths, :rows, :request, :schema

    def records = related_listing.records

    def related_listing
      @related_listing ||=
        relationship.listing(
          request.for_sideload(paths),
          guardian: request.guardian,
          scoped_to: relationship.scoping(association),
        )
    end

    def related_to(row) = related_by_row.fetch(row.record, Records.new([]))

    def related_by_row
      @related_by_row ||=
        association.pair(records.map(&:record)).transform_values { records.fetch_all(it) }
    end

    def owner_records = rows.map(&:record)

    def association = @association ||= schema.association(name.to_sym, owner_records)
  end
end
