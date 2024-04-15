# frozen_string_literal: true

class AddChatSeparateSidebarModeUserOption < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :chat_separate_sidebar_mode, :integer, default: 0, null: false
  end
end
