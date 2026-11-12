# frozen_string_literal: true

class AddChatChannelListSectionSortsToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :chat_channel_list_sort_starred, :integer, default: 0, null: false
    add_column :user_options, :chat_channel_list_sort_dms, :integer, default: 2, null: false
  end
end
