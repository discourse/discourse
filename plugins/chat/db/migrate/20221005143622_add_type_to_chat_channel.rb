# frozen_string_literal: true

class AddTypeToChatChannel < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channels, :type, :string
  end
end
