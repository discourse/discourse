class RemoveDescriptionFromSiteSettings < ActiveRecord::Migration
  def up
    remove_column :site_settings, :description
  end

  def down
    add_column :site_settings, :description, :string
  end
end
