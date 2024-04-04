# frozen_string_literal: true

class RemoveExperimentalObjectsTypeForThemeSettings < ActiveRecord::Migration[7.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'experimental_objects_type_for_theme_settings'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
