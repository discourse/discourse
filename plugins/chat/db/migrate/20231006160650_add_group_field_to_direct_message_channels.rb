# frozen_string_literal: true

class AddGroupFieldToDirectMessageChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :direct_message_channels, :group, :boolean, default: false, null: false
  end
end
