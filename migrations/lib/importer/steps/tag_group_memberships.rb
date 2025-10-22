# frozen_string_literal: true

module Migrations::Importer::Steps
  class TagGroupMemberships < ::Migrations::Importer::CopyStep
    depends_on :tag_groups, :tags

    requires_set :existing_tag_group_memberships,
                 "SELECT tag_group_id, tag_id FROM tag_group_memberships"

    column_names %i[tag_group_id tag_id created_at updated_at]

    total_rows_query <<~SQL, MappingType::TAG_GROUPS, MappingType::TAGS
      SELECT COUNT(*)
      FROM tag_group_memberships
           JOIN mapped.ids mapped_tag_group
             ON tag_group_memberships.tag_group_id = mapped_tag_group.original_id AND mapped_tag_group.type = ?1
           JOIN mapped.ids mapped_tag
             ON tag_group_memberships.tag_id = mapped_tag.original_id AND mapped_tag.type = ?2
    SQL

    rows_query <<~SQL, MappingType::TAG_GROUPS, MappingType::TAGS
      SELECT tag_group_memberships.*,
             mapped_tag_group.discourse_id AS discourse_tag_group_id,
             mapped_tag.discourse_id       AS discourse_tag_id
      FROM tag_group_memberships
           JOIN mapped.ids mapped_tag_group
             ON tag_group_memberships.tag_group_id = mapped_tag_group.original_id AND mapped_tag_group.type = ?1
           JOIN mapped.ids mapped_tag
             ON tag_group_memberships.tag_id = mapped_tag.original_id AND mapped_tag.type = ?2
      ORDER BY discourse_tag_group_id, discourse_tag_id
    SQL

    private

    def transform_row(row)
      tag_group_id = row[:discourse_tag_group_id]
      tag_id = row[:discourse_tag_id]

      return nil unless @existing_tag_group_memberships.add?(tag_group_id, tag_id)

      row[:tag_group_id] = tag_group_id
      row[:tag_id] = tag_id

      super
    end
  end
end
