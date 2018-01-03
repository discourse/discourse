class AddFooterToSiteCustomization < ActiveRecord::Migration[4.2]
  def change
    add_column :site_customizations, :footer, :text
    add_column :site_customizations, :mobile_footer, :text
  end
end
