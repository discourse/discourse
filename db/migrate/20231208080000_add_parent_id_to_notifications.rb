# frozen_string_literal: true

class AddParentIdToNotifications < ActiveRecord::Migration[7.0]
  def up
    add_column :notifications, :parent_id, :integer, null: true

    DB.exec <<~SQL
      UPDATE notifications n
      SET parent_id = cm.id
      FROM chat_mentions cm
      WHERE n.id = cm.notification_id;
    SQL

    add_index :notifications, :parent_id
  end

  def down
    remove_index :notifications, :parent_id
    remove_column :notifications, :parent_id
  end
end
