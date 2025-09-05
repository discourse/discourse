# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserFieldValues < ::Migrations::Importer::CopyStep
    depends_on :users, :user_fields

    requires_set :existing_user_field_values, <<~SQL
      SELECT user_id, name, value
      FROM user_custom_fields
      WHERE user_id > 0 AND name LIKE '#{User::USER_FIELD_PREFIX}%'
    SQL

    table_name :user_custom_fields
    column_names %i[created_at updated_at user_id name value]

    total_rows_query <<~SQL, MappingType::USER_FIELDS, MappingType::USERS
      SELECT COUNT(*)
      FROM user_field_values
           JOIN mapped.ids mapped_user_field
             ON user_field_values.field_id = mapped_user_field.original_id
               AND mapped_user_field.type =  ?1
           JOIN mapped.ids mapped_user
             ON user_field_values.user_id = mapped_user.original_id
               AND mapped_user.type = ?2
    SQL

    rows_query <<~SQL, MappingType::USER_FIELDS, MappingType::USERS
      SELECT user_field_values.*,
              mapped_user_field.discourse_id AS discourse_user_field_id,
              mapped_user.discourse_id       AS discourse_user_id
      FROM user_field_values
           JOIN mapped.ids mapped_user_field
             ON user_field_values.field_id = mapped_user_field.original_id
               AND mapped_user_field.type = ?1
            JOIN mapped.ids mapped_user
              ON user_field_values.user_id = mapped_user.original_id
               AND mapped_user.type = ?2
      ORDER BY user_field_values.user_id
    SQL

    private

    def transform_row(row)
      name = "#{User::USER_FIELD_PREFIX}#{row[:discourse_user_field_id]}"
      user_id = row[:discourse_user_id]

      return nil unless @existing_user_field_values.add?(user_id, name, row[:value])

      row[:name] = name
      row[:user_id] = user_id

      super
    end
  end
end
