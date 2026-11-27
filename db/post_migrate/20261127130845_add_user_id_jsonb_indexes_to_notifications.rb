# frozen_string_literal: true

class AddUserIdJsonbIndexesToNotifications < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  USER_ID_KEYS = %w[
    acting_user_id
    display_user_id
    invited_by_user_id
    mentioned_by_user_id
    original_user_id
    user2_id
  ].freeze

  def up
    USER_ID_KEYS.each do |key|
      execute "DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_#{key}"
      execute <<~SQL
        CREATE INDEX CONCURRENTLY index_notifications_on_data_#{key}
        ON notifications ((data::jsonb ->> '#{key}'))
        WHERE (data::jsonb ->> '#{key}') IS NOT NULL
      SQL
    end
  end

  def down
    USER_ID_KEYS.each do |key|
      execute "DROP INDEX CONCURRENTLY IF EXISTS index_notifications_on_data_#{key}"
    end
  end
end
