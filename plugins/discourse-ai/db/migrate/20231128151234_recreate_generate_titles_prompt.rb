# frozen_string_literal: true

class RecreateGenerateTitlesPrompt < ActiveRecord::Migration[7.0]
  def up
    DB.exec("DELETE FROM completion_prompts WHERE id = -302")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
