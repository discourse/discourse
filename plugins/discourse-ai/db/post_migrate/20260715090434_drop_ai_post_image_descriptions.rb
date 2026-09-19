# frozen_string_literal: true

class DropAiPostImageDescriptions < ActiveRecord::Migration[8.0]
  def up
    execute "DROP TABLE IF EXISTS ai_post_image_descriptions"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
