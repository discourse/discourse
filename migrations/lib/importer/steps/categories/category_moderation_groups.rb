# frozen_string_literal: true

module Migrations::Importer::Steps
  class CategoryModerationGroups < ::Migrations::Importer::CopyStep
    depends_on :categories, :groups

    column_names %i[category_id group_id]

    total_rows_query <<~SQL, MappingType::CATEGORIES, MappingType::GROUPS
      SELECT COUNT(*)
      FROM category_moderation_groups
           JOIN mapped.ids mapped_categories
             ON category_moderation_groups.category_id = mapped_categories.original_id AND mapped_categories.type = ?1
           JOIN mapped.ids mapped_groups
             ON category_moderation_groups.group_id = mapped_groups.original_id AND mapped_groups.type = ?2
    SQL

    rows_query <<~SQL, MappingType::CATEGORIES, MappingType::GROUPS
      SELECT category_moderation_groups*,
             mapped_categories.discourse_id AS discourse_category_id,
             mapped_groups.discourse_id AS discourse_group_id
      FROM category_moderation_groups
           JOIN mapped.ids mapped_categories
             ON category_moderation_groups.category_id = mapped_categories.original_id AND mapped_categories.type = ?1
           JOIN mapped.ids mapped_groups
             ON category_moderation_groups.group_id = mapped_groups.original_id AND mapped_groups.type = ?2
      ORDER BY discourse_category_id, discourse_group_id
    SQL

    def execute
      @existing_category_moderation_groups = Hash.new { |h, k| h[k] = Set.new }

      @discourse_db
        .query_array(
          "SELECT category_id, group_id FROM category_moderation_groups WHERE group_id > 0",
        )
        .each { |row| @existing_category_moderation_groups[row[0]].add(row[1]) }

      super
    end

    private

    def transform_row(row)
      category_id = row[:discourse_category_id]
      group_id = row[:discourse_group_id]

      return nil unless @existing_category_moderation_groups[category_id].add?(group_id)

      row[:category_id] = category_id
      row[:group_id] = group_id

      super
    end
  end
end
