# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserCustomFields < ::Migrations::Importer::CopyStep
    depends_on :users

    requires_set :existing_user_custom_fields, <<~SQL
      SELECT user_id, name, value
      FROM user_custom_fields
      WHERE user_id > 0 AND name NOT LIKE '#{User::USER_FIELD_PREFIX}%'
    SQL

    column_names %i[created_at updated_at user_id name value]

    total_rows_query <<~SQL, MappingType::USERS
      SELECT COUNT(*)
      FROM user_custom_fields
           JOIN mapped.ids mapped_user
             ON user_custom_fields.user_id = mapped_user.original_id
               AND mapped_user.type = ?
    SQL

    rows_query <<~SQL, MappingType::USERS
      SELECT user_custom_fields.*,
              mapped_user.discourse_id AS discourse_user_id
      FROM user_custom_fields
           JOIN mapped.ids mapped_user
              ON user_custom_fields.user_id = mapped_user.original_id
               AND mapped_user.type = ?
      ORDER BY user_custom_fields.user_id
    SQL

    private

    def transform_row(row)
      name = row[:name]
      user_id = row[:discourse_user_id]

      if name.start_with?(User::USER_FIELD_PREFIX)
        puts "    '#{name}': Name cannot start with #{User::USER_FIELD_PREFIX}"
        return nil
      end

      return nil unless @existing_user_custom_fields.add?(user_id, name, row[:value])

      row[:user_id] = user_id

      super
    end
  end
end
