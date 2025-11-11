# frozen_string_literal: true

class AddAllowChatToAiPersona < ActiveRecord::Migration[7.0]
  def change
    add_column :ai_personas, :allow_chat, :boolean, default: false, null: false
  end
end
