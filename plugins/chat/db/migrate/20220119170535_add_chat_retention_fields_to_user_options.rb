# frozen_string_literal: true
class AddChatRetentionFieldsToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :dismissed_channel_retention_reminder, :boolean, null: true
    add_column :user_options, :dismissed_dm_retention_reminder, :boolean, null: true
  end
end
