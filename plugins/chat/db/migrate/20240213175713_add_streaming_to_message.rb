# frozen_string_literal: true

class AddStreamingToMessage < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_messages, :streaming, :boolean, null: false, default: false
  end
end
