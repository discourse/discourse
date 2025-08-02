# frozen_string_literal: true

class DeleteExperimentalComposerUploadSetting < ActiveRecord::Migration[6.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_experimental_composer_uploader'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
