# frozen_string_literal: true
class AddJsonbIndexesToNotifications < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_original_username
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_notifications_on_data_original_username
      ON notifications ((data :: JSONB ->> 'original_username'))
      WHERE (data :: JSONB ->> 'original_username') IS NOT NULL;
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_display_username
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_notifications_on_data_display_username
      ON notifications ((data :: JSONB ->> 'display_username'))
      WHERE (data :: JSONB ->> 'display_username') IS NOT NULL;
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_username
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_notifications_on_data_username
      ON notifications ((data :: JSONB ->> 'username'))
      WHERE (data :: JSONB ->> 'username') IS NOT NULL;
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_username2
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_notifications_on_data_username2
      ON notifications ((data :: JSONB ->> 'username2'))
      WHERE (data :: JSONB ->> 'username2') IS NOT NULL;
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX index_notifications_on_data_original_username;
      DROP INDEX index_notifications_on_data_display_username;
      DROP INDEX index_notifications_on_data_username;
      DROP INDEX index_notifications_on_data_username2;
    SQL
  end
end
