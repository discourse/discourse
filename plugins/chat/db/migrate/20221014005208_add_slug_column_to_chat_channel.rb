# frozen_string_literal: true

class AddSlugColumnToChatChannel < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channels, :slug, :string

    add_index :chat_channels, :slug
  end
end
