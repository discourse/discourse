# frozen_string_literal: true

module Migrations::Importer::Steps
  class TagGroupPermissions < ::Migrations::Importer::CopyStep
    PERMISSION_TYPES = TagGroupPermission.permission_types.values.to_set.freeze
    DEFAULT_PERMISSION_TYPE = TagGroupPermission.permission_types[:full]

    depends_on :tag_groups, :groups

    requires_set :existing_tag_group_permissions,
                 "SELECT tag_group_id, group_id, permission_type FROM tag_group_permissions"

    column_names %i[tag_group_id group_id permission_type created_at updated_at]

    total_rows_query <<~SQL, MappingType::TAG_GROUPS, MappingType::GROUPS
      SELECT COUNT(*)
      FROM tag_group_permissions
           JOIN mapped.ids mapped_tag_group
              ON tag_group_permissions.tag_group_id = mapped_tag_group.original_id
                 AND mapped_tag_group.type = ?1
           JOIN mapped.ids mapped_group
              ON tag_group_permissions.group_id = mapped_group.original_id
                 AND mapped_group.type = ?2
    SQL

    rows_query <<~SQL, MappingType::TAG_GROUPS, MappingType::GROUPS
      SELECT tag_group_permissions.*,
             mapped_tag_group.discourse_id AS discourse_tag_group_id,
             mapped_group.discourse_id AS discourse_group_id
      FROM tag_group_permissions
           JOIN mapped.ids mapped_tag_group
             ON tag_group_permissions.tag_group_id = mapped_tag_group.original_id
                AND mapped_tag_group.type = ?1
           JOIN mapped.ids mapped_group
             ON tag_group_permissions.group_id = mapped_group.original_id
                AND mapped_group.type = ?2
      ORDER BY tag_group_permissions.tag_group_id,
               tag_group_permissions.group_id
    SQL

    private

    def transform_row(row)
      tag_group_id = row[:discourse_tag_group_id]
      group_id = row[:discourse_group_id]

      permission_type =
        ensure_valid_value(
          value: row[:permission_type],
          allowed_set: PERMISSION_TYPES,
          default_value: DEFAULT_PERMISSION_TYPE,
        ) do |value, _default_value|
          puts "    Tag group #{tag_group_id}, Group #{group_id}: Invalid permission_type '#{value}'"
        end

      unless @existing_tag_group_permissions.add?(tag_group_id, group_id, permission_type)
        return nil
      end

      row[:tag_group_id] = tag_group_id
      row[:group_id] = group_id
      row[:permission_type] = permission_type

      super
    end
  end
end
