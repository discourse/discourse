# frozen_string_literal: true
class AddNameToChatChannel < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_channels, :name, :string, null: true
  end
end
