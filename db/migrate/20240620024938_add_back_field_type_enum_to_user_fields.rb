# frozen_string_literal: true

class AddBackFieldTypeEnumToUserFields < ActiveRecord::Migration[7.0]
  def change
    # NOTE: This is here to undo the swap done in SwapFieldTypeWithFieldTypeEnumOnUserFields,
    #       as that change was breaking the AR cache until the application is rebooted.
    #       The condition here is to ensure it's only executed if that post-migration has been
    #       applied.
    if !ActiveRecord::Base.connection.column_exists?(:user_fields, :field_type_enum)
      add_column :user_fields, :field_type_enum, :integer
      change_column_null :user_fields, :field_type, true

      execute(<<~SQL)
        UPDATE user_fields
        SET field_type_enum = field_type
      SQL

      change_column_null :user_fields, :field_type_enum, false
    end
  end
end
