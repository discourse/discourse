# frozen_string_literal: true

class AddIsImageGenerationToolToAiTools < ActiveRecord::Migration[7.1]
  def up
    add_column :ai_tools, :is_image_generation_tool, :boolean, default: false, null: false

    # Backfill existing tools
    execute <<~SQL
      UPDATE ai_tools
      SET is_image_generation_tool = true
      WHERE enabled = true
        AND parameters::text LIKE '%"name":"prompt"%'
        AND script LIKE '%upload.create%'
        AND script LIKE '%chain.setCustomRaw%'
    SQL
  end

  def down
    remove_column :ai_tools, :is_image_generation_tool
  end
end
