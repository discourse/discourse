# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserFieldOptions < ::Migrations::Importer::CopyStep
    depends_on :user_fields

    requires_set :existing_user_field_options, "SELECT user_field_id, value FROM user_field_options"

    column_names %i[user_field_id value created_at updated_at]

    total_rows_query <<~SQL, MappingType::USER_FIELDS
      SELECT COUNT(*)
      FROM user_field_options
           JOIN mapped.ids mapped_user_field
             ON user_field_options.user_field_id = mapped_user_field.original_id
                AND mapped_user_field.type = ?
    SQL

    rows_query <<~SQL, MappingType::USER_FIELDS
      SELECT user_field_options.*,
            mapped_user_field.discourse_id AS discourse_user_field_id
      FROM user_field_options
           JOIN mapped.ids mapped_user_field
             ON user_field_options.user_field_id = mapped_user_field.original_id
                AND mapped_user_field.type = ?
      ORDER BY user_field_options.user_field_id, user_field_options.value
    SQL

    private

    def transform_row(row)
      user_field_id = row[:discourse_user_field_id]

      return nil unless @existing_user_field_options.add?(user_field_id, row[:value])

      row[:user_field_id] = user_field_id

      super
    end
  end
end
