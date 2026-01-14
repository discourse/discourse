# frozen_string_literal: true

module Migrations::Importer::Steps
  class BadgeGroupings < ::Migrations::Importer::CopyStep
    MAX_NAME_LENGTH = 100
    MAX_DESCRIPTION_LENGTH = 500

    store_mapped_ids true

    requires_mapping :ids_by_name, "SELECT LOWER(name), id FROM badge_groupings"

    column_names %i[id name description position created_at updated_at]

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
             ROW_NUMBER() OVER (
              ORDER BY COALESCE(badge_groupings.position, 0), badge_groupings.ROWID
            ) AS normalized_position
      FROM badge_groupings
           LEFT JOIN mapped.ids mapped_badge_grouping
             ON badge_groupings.original_id = mapped_badge_grouping.original_id
               AND mapped_badge_grouping.type = ?
      WHERE mapped_badge_grouping.original_id IS NULL
      ORDER BY normalized_position
    SQL

    def execute
      @max_position = BadgeGrouping.maximum(:position) || 0

      super
    end

    private

    def transform_row(row)
      if (existing_id = @ids_by_name[row[:name].downcase])
        row[:id] = existing_id

        return nil
      end

      name = row[:name]
      description = row[:description]

      row[:name] = name[0, MAX_NAME_LENGTH] if name.length > MAX_NAME_LENGTH
      if description && description.length > MAX_DESCRIPTION_LENGTH
        row[:description] = description[0, MAX_DESCRIPTION_LENGTH]
      end
      row[:position] = @max_position + row[:normalized_position]

      super
    end
  end
end
