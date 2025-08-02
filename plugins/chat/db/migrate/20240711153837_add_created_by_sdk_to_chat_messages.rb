# frozen_string_literal: true
class AddCreatedBySdkToChatMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :chat_messages, :created_by_sdk, :boolean
  end
end
