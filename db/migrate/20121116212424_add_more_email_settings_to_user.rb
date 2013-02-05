class AddMoreEmailSettingsToUser < ActiveRecord::Migration
  def change
    add_column :users, :email_private_messages, :boolean, default: true
    add_column :users, :email_mentions, :boolean, default: true
  end
end
