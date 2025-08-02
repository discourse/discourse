# frozen_string_literal: true

class AddTopToSiteCustomization < ActiveRecord::Migration[4.2]
  def up
    add_column :site_customizations, :top, :text
    add_column :site_customizations, :mobile_top, :text

    execute <<-SQL
      UPDATE site_customizations
         SET top = (SELECT value FROM site_texts WHERE text_type = 'top' LIMIT 1),
             mobile_top = (SELECT value FROM site_texts WHERE text_type = 'top' LIMIT 1),
             head_tag = (SELECT value FROM site_texts WHERE text_type = 'head' LIMIT 1),
             body_tag = (SELECT value FROM site_texts WHERE text_type = 'bottom' LIMIT 1)
       WHERE name = 'Migrated from Site Text'
    SQL
  end

  def down
    remove_column :site_customizations, :top
    remove_column :site_customizations, :mobile_top
  end
end
