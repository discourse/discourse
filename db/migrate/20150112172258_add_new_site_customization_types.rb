class AddNewSiteCustomizationTypes < ActiveRecord::Migration
  def change
    add_column :site_customizations, :head_tag, :text
    add_column :site_customizations, :body_tag, :text
  end
end
