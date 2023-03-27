# frozen_string_literal: true
class AddCookedToChatMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_messages, :cooked, :text
    add_column :chat_messages, :cooked_version, :integer
  end
end
