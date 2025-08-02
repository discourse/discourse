# frozen_string_literal: true

class RemoveEnableExperimentalImageUploaderSiteSetting < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'enable_experimental_image_uploader'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
