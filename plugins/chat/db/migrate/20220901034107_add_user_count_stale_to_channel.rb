# frozen_string_literal: true

class AddUserCountStaleToChannel < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channels, :user_count_stale, :boolean, default: false, null: false
  end
end
