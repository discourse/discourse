# frozen_string_literal: true

class ChangeNotificationsToBigInt < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    change_column :notifications, :id, :bigint
    change_column :users, :seen_notification_id, :bigint
    change_column :user_badges, :notification_id, :bigint
    change_column :shelved_notifications, :notification_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
