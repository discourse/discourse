# frozen_string_literal: true

class SetMultiusersDirectMessageChannelsAsGroup < ActiveRecord::Migration[7.0]
  def change
    execute <<-SQL
      UPDATE direct_message_channels
      SET "group" = true
      WHERE id IN (
        SELECT direct_message_channel_id
        FROM direct_message_users
        GROUP BY direct_message_channel_id
        HAVING COUNT(user_id) > 2
      );
    SQL
  end
end
