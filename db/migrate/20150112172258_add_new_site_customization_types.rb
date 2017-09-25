class AddNewSiteCustomizationTypes < ActiveRecord::Migration[4.2]
  def change
    add_column :site_customizations, :head_tag, :text
    add_column :site_customizations, :body_tag, :text
  end
end
