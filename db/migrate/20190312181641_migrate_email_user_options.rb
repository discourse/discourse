# frozen_string_literal: true

class MigrateEmailUserOptions < ActiveRecord::Migration[5.2]
  def up
    # see UserOption.email_level_types
    # always = 0, only_while_away: 1, never: 2

    add_column :user_options, :email_level, :integer, default: 1, null: false
    add_column :user_options, :email_messages_level, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE user_options
      SET email_level = CASE
        WHEN email_direct AND email_always
        THEN 0
        WHEN email_direct AND email_always IS NOT TRUE
        THEN 1
        ELSE 2
      END,
      email_messages_level = CASE
        WHEN email_private_messages
        THEN 0
        ELSE 2
      END
    SQL
  end

  def down
    # See postmigration: 20190312194528_drop_email_user_options_columns.rb
  end
end
