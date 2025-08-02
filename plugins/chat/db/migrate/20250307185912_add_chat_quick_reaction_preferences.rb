# frozen_string_literal: true
class AddChatQuickReactionPreferences < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :chat_quick_reaction_type, :integer, default: 0, null: false
    add_column :user_options, :chat_quick_reactions_custom, :string
  end
end
