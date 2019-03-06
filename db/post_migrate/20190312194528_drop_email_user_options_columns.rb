require 'migration/column_dropper'

class DropEmailUserOptionsColumns < ActiveRecord::Migration[5.2]
  def up
    Migration::ColumnDropper.execute_drop(:user_options, %i{email_direct})
    Migration::ColumnDropper.execute_drop(:user_options, %i{email_always})
    Migration::ColumnDropper.execute_drop(:user_options, %i{email_private_messages})
  end

  def down
    add_column :user_options, :email_direct, :boolean, default: true, null: false
    add_column :user_options, :email_private_messages, :boolean, default: true, null: false
    add_column :user_options, :email_always, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE user_options
      SET email_direct = CASE
        WHEN email_level = '0' OR email_level = '1'
        THEN TRUE ELSE FALSE
      END,
      email_private_messages = CASE
        WHEN email_messages_level = '0' OR email_messages_level = '1'
        THEN TRUE ELSE FALSE
      END,
      email_always = CASE
        WHEN email_level = '0'
        THEN TRUE ELSE FALSE
      END
    SQL

    remove_column :user_options, :email_level
    remove_column :user_options, :email_messages_level
  end
end
