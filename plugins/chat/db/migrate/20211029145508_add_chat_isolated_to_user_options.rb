# frozen_string_literal: true

class AddChatIsolatedToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :chat_isolated, :boolean, null: true
  end
end
