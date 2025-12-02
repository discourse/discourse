# frozen_string_literal: true

class RemoveExperimentalLightboxSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name='experimental_lightbox'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
