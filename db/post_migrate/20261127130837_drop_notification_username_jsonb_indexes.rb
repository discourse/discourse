# frozen_string_literal: true

class DropNotificationUsernameJsonbIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  LEGACY_USERNAME_KEYS = %w[original_username display_username username username2].freeze

  def up
    LEGACY_USERNAME_KEYS.each do |key|
      execute "DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_#{key}"
    end
  end

  def down
    LEGACY_USERNAME_KEYS.each do |key|
      execute "DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_#{key}"
      execute <<~SQL
        CREATE INDEX CONCURRENTLY index_notifications_on_data_#{key}
        ON notifications ((data::jsonb ->> '#{key}'))
        WHERE (data::jsonb ->> '#{key}') IS NOT NULL
      SQL
    end
  end
end
