# frozen_string_literal: true
class AddChatEnabledToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :chat_enabled, :boolean, default: true, null: false
  end
end
