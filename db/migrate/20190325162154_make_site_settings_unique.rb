# frozen_string_literal: true

class MakeSiteSettingsUnique < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      DELETE
      FROM site_settings a USING site_settings b
      WHERE a.id < b.id AND a.name = b.name
    SQL

    add_index :site_settings, [:name], unique: true
  end

  def down
    remove_index :site_settings, [:name]
  end
end
