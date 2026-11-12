# frozen_string_literal: true

class AddChatChannelListSectionFiltersToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :chat_channel_list_filter_starred, :integer, default: 0, null: false
    add_column :user_options, :chat_channel_list_filter_dms, :integer, default: 0, null: false
  end
end
