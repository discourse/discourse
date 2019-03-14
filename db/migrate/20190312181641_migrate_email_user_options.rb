class MigrateEmailUserOptions < ActiveRecord::Migration[5.2]
  def up
    add_column :user_options, :email_level, :integer, default: UserOption.email_level_types[:only_when_away], null: false
    add_column :user_options, :email_messages_level, :integer, default: UserOption.email_level_types[:always], null: false

    execute <<~SQL
      UPDATE user_options
      SET email_level = CASE
        WHEN email_direct IS TRUE AND email_always IS TRUE
        THEN #{UserOption.email_level_types[:always]}
        WHEN email_direct IS TRUE AND email_always IS NOT TRUE
        THEN #{UserOption.email_level_types[:only_when_away]}
        ELSE #{UserOption.email_level_types[:never]}
      END,
      email_messages_level = CASE
        WHEN email_private_messages IS TRUE
        THEN #{UserOption.email_level_types[:always]}
        ELSE #{UserOption.email_level_types[:never]}
      END
    SQL
  end

  def down
    # See postmigration: 20190312194528_drop_email_user_options_columns.rb
  end
end
