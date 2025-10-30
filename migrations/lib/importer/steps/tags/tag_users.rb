# frozen_string_literal: true

module Migrations::Importer::Steps
  class TagUsers < ::Migrations::Importer::CopyStep
    NOTIFICATION_LEVELS = TagUser.notification_levels.values.to_set.freeze
    DEFAULT_NOTIFICATION_LEVEL = TagUser.notification_levels[:regular]

    depends_on :tags, :users

    requires_set :existing_tag_users, "SELECT tag_id, user_id FROM tag_users"

    column_names %i[tag_id user_id notification_level created_at updated_at]

    total_rows_query <<~SQL, MappingType::TAGS, MappingType::USERS
      SELECT COUNT(*)
      FROM tag_users
           JOIN mapped.ids mapped_tag
             ON tag_users.tag_id = mapped_tag.original_id AND mapped_tag.type = ?1
           JOIN mapped.ids mapped_user
             ON tag_users.user_id = mapped_user.original_id AND mapped_user.type = ?2
    SQL

    rows_query <<~SQL, MappingType::TAGS, MappingType::USERS
      SELECT tag_users.*,
             mapped_tag.discourse_id AS discourse_tag_id,
             mapped_user.discourse_id AS discourse_user_id
      FROM tag_users
           JOIN mapped.ids mapped_tag
             ON tag_users.tag_id = mapped_tag.original_id AND mapped_tag.type = ?1
           JOIN mapped.ids mapped_user
             ON tag_users.user_id = mapped_user.original_id AND mapped_user.type = ?2
      ORDER BY tag_id, user_id
    SQL

    private

    def transform_row(row)
      tag_id = row[:discourse_tag_id]
      user_id = row[:discourse_user_id]

      return nil unless @existing_tag_users.add?(tag_id, user_id)

      row[:tag_id] = tag_id
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
