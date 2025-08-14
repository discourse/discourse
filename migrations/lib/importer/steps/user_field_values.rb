# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserFieldValues < ::Migrations::Importer::CopyStep
    depends_on :user_fields

    requires_set :existing_user_field_values,
                 "SELECT user_id, name FROM user_custom_fields WHERE user_id > 0"

    column_names %i[created_at field_id user_id name value]

    total_rows_query <<~SQL, MappingType::USER_FIELDS, MappingType::USERS
      SELECT COUNT(*)
      FROM user_custom_fields
           JOIN mapped.ids mapped_user_field
             ON user_custom_fields.field_id = mapped_user_field.original_id
               AND mapped_user_field.type =  ?1
           JOIN mapped.ids mapped_user
             ON user_custom_fields.user_id = mapped_user.original_id
               AND mapped_user.type = ?2
    SQL

    rows_query <<~SQL, MappingType::USER_FIELDS, MappingType::USERS
      SELECT user_custom_fields.*,
              mapped_user_field.discourse_id AS discourse_user_field_id,
              mapped_user.discourse_id       AS discourse_user_id
      FROM user_custom_fields
           JOIN mapped.ids mapped_user_field
             ON user_custom_fields.field_id = mapped_user_field.original_id
               AND mapped_user_field.type = ?1
            JOIN mapped.ids mapped_user
              ON user_custom_fields.user_id = mapped_user.original_id
               AND mapped_user.type = ?2
      ORDER BY user_custom_fields.user_id
    SQL

    private

    def transform_row(row)
      name = "#{User::USER_FIELD_PREFIX}#{row[:discourse_user_field_id]}"
      user_id = row[:discourse_user_id]

      return nil unless @existing_user_field_values.add?(user_id, name)

      row[:name] = name
      row[:user_id] = user_id

      super
    end
  end
end
