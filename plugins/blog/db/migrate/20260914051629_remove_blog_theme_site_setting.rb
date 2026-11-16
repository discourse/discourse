# frozen_string_literal: true

class RemoveBlogThemeSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'discourse_blog_theme'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
