# frozen_string_literal: true

class AddMoreEmailSettingsToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :email_private_messages, :boolean, default: true
    add_column :users, :email_mentions, :boolean, default: true
  end
end
