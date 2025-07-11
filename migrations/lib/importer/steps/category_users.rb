# frozen_string_literal: true

module Migrations::Importer::Steps
  class CategoryUsers < ::Migrations::Importer::CopyStep
    DEFAULT_NOTIFICATION_LEVEL = CategoryUser.default_notification_level
    VALID_NOTIFICATION_LEVELS = CategoryUser.notification_levels.values.to_set.freeze

    depends_on :categories, :users

    column_names %i[category_id last_seen_at notification_level user_id]

    total_rows_query <<~SQL, MappingType::CATEGORIES, MappingType::USERS
      SELECT COUNT(*)
      FROM category_users
           JOIN mapped.ids mapped_categories
             ON category_users.category_id = mapped_categories.original_id AND mapped_categories.type = ?1
           JOIN mapped.ids mapped_users
             ON category_users.user_id = mapped_users.original_id AND mapped_users.type = ?2
    SQL

    rows_query <<~SQL, MappingType::CATEGORIES, MappingType::USERS
      SELECT category_users.*,
             mapped_categories.discourse_id AS discourse_category_id,
             mapped_users.discourse_id AS discourse_user_id
      FROM category_users
           JOIN mapped.ids mapped_categories
             ON category_users.category_id = mapped_categories.original_id AND mapped_categories.type = ?1
           JOIN mapped.ids mapped_users
             ON category_users.user_id = mapped_users.original_id AND mapped_users.type = ?2
      ORDER BY discourse_category_id, discourse_user_id
    SQL

    def execute
      @existing_category_users = Hash.new { |h, k| h[k] = Set.new }

      @discourse_db
        .query_array("SELECT category_id, user_id FROM category_users WHERE user_id >= 0")
        .each { |row| @existing_category_users[row[0]].add(row[1]) }

      super
    end

    private

    def transform_row(row)
      category_id = row[:discourse_category_id]
      user_id = row[:discourse_user_id]

      return nil unless @existing_category_users[category_id].add?(user_id)

      row[:category_id] = category_id
      row[:user_id] = user_id
      row[:notification_level] = ensure_valid_value(
        value: row[:notification_level],
        allowed_set: VALID_NOTIFICATION_LEVELS,
        default_value: DEFAULT_NOTIFICATION_LEVEL,
      )

      super
    end
  end
end
