# frozen_string_literal: true
class AddAiAskAiDefaultToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :ai_ask_ai_default, :boolean, default: false, null: false
  end
end
