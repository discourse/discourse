# frozen_string_literal: true

class DropOldUnreadPmNotificationIndices < ActiveRecord::Migration[6.0]
  def up
    DB.exec("DROP INDEX IF EXISTS index_notifications_on_user_id_and_id")
    DB.exec("DROP INDEX IF EXISTS index_notifications_on_read_or_n_type")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
