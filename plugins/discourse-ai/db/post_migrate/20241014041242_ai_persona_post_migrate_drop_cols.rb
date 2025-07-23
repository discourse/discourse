# frozen_string_literal: true
class AiPersonaPostMigrateDropCols < ActiveRecord::Migration[7.1]
  def change
    remove_columns :ai_personas, :allow_chat
    remove_columns :ai_personas, :mentionable
  end
end
