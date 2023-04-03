# frozen_string_literal: true

class AddChatHeaderIndicatorPreference < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :chat_header_indicator_preference, :integer, default: 0, null: false
  end
end
