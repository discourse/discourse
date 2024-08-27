# frozen_string_literal: true

class CopyShelvedNotificationsNotificationIdIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute "DROP INDEX #{Rails.env.test? ? "" : "CONCURRENTLY"} IF EXISTS index_shelved_notifications_on_new_notification_id"
    execute "CREATE INDEX #{Rails.env.test? ? "" : "CONCURRENTLY"} index_shelved_notifications_on_new_notification_id ON shelved_notifications (new_notification_id)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
