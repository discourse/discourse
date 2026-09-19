# frozen_string_literal: true

class AddSendShortcutToUserOptions < ActiveRecord::Migration[8.0]
  def change
    # send_shortcut enum: enter: 0, meta_enter: 1. Default to `enter` to
    # preserve the prior chat_send_shortcut default.
    add_column :user_options, :send_shortcut, :integer, null: false, default: 0
  end
end
