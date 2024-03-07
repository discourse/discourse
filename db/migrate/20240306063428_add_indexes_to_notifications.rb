# frozen_string_literal: true

class AddIndexesToNotifications < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    DROP INDEX IF EXISTS index_notifications_user_menu_ordering
    SQL

    execute <<~SQL
    CREATE INDEX CONCURRENTLY index_notifications_user_menu_ordering
    ON notifications (
      user_id,
      (high_priority AND NOT read) DESC,
      (NOT read) DESC,
      created_at DESC
    );
    SQL

    execute <<~SQL
    DROP INDEX IF EXISTS index_notifications_user_menu_ordering_deprioritized_likes
    SQL

    execute <<~SQL
    CREATE INDEX CONCURRENTLY index_notifications_user_menu_ordering_deprioritized_likes
    ON notifications (
      user_id,
      (high_priority AND NOT read) DESC,
      (NOT read AND notification_type NOT IN (5,19,25)) DESC,
      created_at DESC
    );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
