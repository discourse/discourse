# frozen_string_literal: true

class TruncateUserStatusTo100Characters < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE user_statuses SET description = left(description, 100)"
    execute "UPDATE user_statuses SET emoji = left(emoji, 100)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
