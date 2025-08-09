# frozen_string_literal: true

module Migrations::Importer::Steps
  class BadgeGroupings < ::Migrations::Importer::CopyStep
    store_mapped_ids true

    requires_mapping :ids_by_name, "SELECT LOWER(name), id FROM badge_groupings"

    column_names %i[id name description position created_at]

    total_rows_query <<~SQL, MappingType::BADGE_GROUPINGS
      SELECT COUNT(*)
      FROM badge_groupings
           LEFT JOIN mapped.ids mapped_badge_grouping
             ON badge_groupings.original_id = mapped_badge_grouping.original_id
               AND mapped_badge_grouping.type = ?
      WHERE mapped_badge_grouping.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::BADGE_GROUPINGS
      SELECT badge_groupings.*,
             COALESCE(badge_groupings.position, 0) AS position
      FROM badge_groupings
           LEFT JOIN mapped.ids mapped_badge_grouping
             ON badge_groupings.original_id = mapped_badge_grouping.original_id
               AND mapped_badge_grouping.type = ?
      WHERE mapped_badge_grouping.original_id IS NULL
      ORDER BY badge_groupings.original_id
    SQL

    def execute
      # TODO:(selase) Use @discourse_db.query_value here
      @max_position = BadgeGrouping.maximum(:position) || 0

      super
    end

    private

    def transform_row(row)
      name_lower = row[:name].downcase
      if (existing_id = @ids_by_name[name_lower])
        row[:id] = existing_id

        return nil
      end

      # TODO:selase) Fix position calculation
      @max_position += 1
      row[:position] += @max_position

      super
    end
  end
end
