# frozen_string_literal: true

class AddChatChannelListPreferencesToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :chat_channel_list_filter, :integer, default: 0, null: false
    add_column :user_options, :chat_channel_list_sort, :integer, default: 0, null: false
  end
end
