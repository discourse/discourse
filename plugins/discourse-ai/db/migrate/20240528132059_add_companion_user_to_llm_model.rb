# frozen_string_literal: true

class AddCompanionUserToLlmModel < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_models, :user_id, :integer
    add_column :llm_models, :enabled_chat_bot, :boolean, null: false, default: false
  end
end
