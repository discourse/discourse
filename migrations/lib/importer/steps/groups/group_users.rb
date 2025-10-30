# frozen_string_literal: true

module Migrations::Importer::Steps
  class GroupUsers < ::Migrations::Importer::CopyStep
    NOTIFICATION_LEVELS = GroupUser.notification_levels.values.to_set.freeze
    DEFAULT_NOTIFICATION_LEVEL = GroupUser.notification_levels[:tracking]

    depends_on :groups, :users

    requires_set :existing_group_users,
                 "SELECT group_id, user_id FROM group_users WHERE user_id > 0"

    column_names %i[group_id user_id created_at updated_at owner notification_level]

    total_rows_query <<~SQL, MappingType::GROUPS, MappingType::USERS
      SELECT COUNT(*)
      FROM group_users
           JOIN mapped.ids mapped_groups
             ON group_users.group_id = mapped_groups.original_id AND mapped_groups.type = ?1
           JOIN mapped.ids mapped_users
             ON group_users.user_id = mapped_users.original_id AND mapped_users.type = ?2
    SQL

    rows_query <<~SQL, MappingType::GROUPS, MappingType::USERS
       SELECT group_users.*,
             mapped_groups.discourse_id AS discourse_group_id,
             mapped_users.discourse_id AS discourse_user_id
      FROM group_users
           JOIN mapped.ids mapped_groups
             ON group_users.group_id = mapped_groups.original_id AND mapped_groups.type = ?1
           JOIN mapped.ids mapped_users
             ON group_users.user_id = mapped_users.original_id AND mapped_users.type = ?2
      ORDER BY discourse_group_id, discourse_user_id
    SQL

    private

    def transform_row(row)
      group_id = row[:discourse_group_id]
      user_id = row[:discourse_user_id]

      return nil unless @existing_group_users.add?(group_id, user_id)

      row[:owner] ||= false
      row[:group_id] = group_id
      row[:user_id] = user_id
      row[:notification_level] = ensure_valid_value(
        value: row[:notification_level],
        allowed_set: NOTIFICATION_LEVELS,
        default_value: DEFAULT_NOTIFICATION_LEVEL,
      )

      super
    end
  end
end
