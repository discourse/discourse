# frozen_string_literal: true

class AdminDashboardReportsSection
  def self.build(guardian:)
    new(guardian: guardian).build
  end

  def initialize(guardian:)
    @guardian = guardian
  end

  def build
    { items: visible_items.map { |_row, resolved| serialize(resolved) } }
  end

  private

  attr_reader :guardian

  def visible_items
    rows = AdminDashboardReport.order(created_at: :desc).to_a
    resolved_by_row_id = resolve_rows(rows)

    # When more rows resolve than VISIBLE_CAP allows, the older overflow
    # is hidden — clip by created_at recency first, then re-sort the
    # survivors by the admin's chosen position.
    rows
      .filter_map { |row| (obj = resolved_by_row_id[row.id]) && [row, obj] }
      .first(AdminDashboardReport::VISIBLE_CAP)
      .sort_by { |row, _obj| row.position }
  end

  def resolve_rows(rows)
    rows
      .group_by(&:source)
      .each_with_object({}) do |(source, group), resolved|
        provider = AdminDashboard::Reports::Registry.provider_for(source)
        next if provider.nil?

        objects_by_identifier = provider.resolve_many(group.map(&:identifier), guardian: guardian)
        group.each { |row| resolved[row.id] = objects_by_identifier[row.identifier] }
      end
  end

  def serialize(resolved)
    {
      source: resolved.source,
      identifier: resolved.identifier,
      title: resolved.title,
      description: resolved.description,
    }
  end
end
