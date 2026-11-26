# frozen_string_literal: true

class AddInteractiveBotToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :interactive_bot, :boolean, default: false, null: false
  end
end
