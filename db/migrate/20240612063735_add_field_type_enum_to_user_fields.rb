# frozen_string_literal: true

class AddFieldTypeEnumToUserFields < ActiveRecord::Migration[7.0]
  def change
    add_column :user_fields, :field_type_enum, :integer

    up_only do
      execute(<<~SQL)
        UPDATE user_fields
        SET field_type_enum =
          CASE
            WHEN field_type = 'text' THEN 0
            WHEN field_type = 'confirm' THEN 1
            WHEN field_type = 'dropdown' THEN 2
            WHEN field_type = 'multiselect' THEN 3
          END
      SQL

      change_column_null :user_fields, :field_type, true
      change_column_null :user_fields, :field_type_enum, false
    end
  end
end
