# frozen_string_literal: true

module Migrations::Importer::Steps
  class TagGroups < ::Migrations::Importer::CopyStep
    MAX_NAME_LENGTH = 100

    depends_on :tags
    store_mapped_ids true

    requires_mapping :existing_tag_group_by_name, "SELECT LOWER(name), id FROM tag_groups"

    column_names %i[id name one_per_topic created_at updated_at parent_tag_id]

    total_rows_query <<~SQL, MappingType::TAG_GROUPS
      SELECT COUNT(*)
      FROM tag_groups
           LEFT JOIN mapped.ids mapped_tag_group
              ON tag_groups.original_id = mapped_tag_group.original_id
                 AND mapped_tag_group.type = ?
      WHERE mapped_tag_group.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::TAG_GROUPS, MappingType::TAGS
      SELECT tag_groups.*,
             mapped_tag.discourse_id AS discourse_parent_tag_id
      FROM tag_groups
           LEFT JOIN mapped.ids mapped_tag_group
             ON tag_groups.original_id = mapped_tag_group.original_id
                AND mapped_tag_group.type = ?1
           LEFT JOIN mapped.ids mapped_tag
             ON tag_groups.parent_tag_id = mapped_tag.original_id AND mapped_tag.type = ?2
      WHERE mapped_tag_group.original_id IS NULL
      ORDER BY tag_groups.original_id
    SQL

    def execute
      # TODO:(selase) Replicated this from the existing importer
      #      Figure out how to handle updating/restoring these site settings
      SiteSetting.tags_listed_by_group = true

      super
    end

    private

    def transform_row(row)
      name = row[:name].strip

      return nil if (row[:id] = @existing_tag_group_by_name[name.downcase])

      row[:one_per_topic] ||= false
      row[:name] = name[0...MAX_NAME_LENGTH]
      row[:parent_tag_id] = row[:discourse_parent_tag_id]

      super
    end
  end
end
