# frozen_string_literal: true
class AddReadNotificationIndex < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    # doing this by hand cause I am ordering id DESC
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY index_notifications_on_read_or_n_type
      ON notifications(user_id, id DESC, read, topic_id)
      WHERE read or notification_type <> 6
    SQL

    # we need to do this to ensure this index hits
    # on some sites this was missing prior
    execute <<~SQL
      VACUUM ANALYZE notifications
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
