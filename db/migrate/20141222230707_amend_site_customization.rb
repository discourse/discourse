class AmendSiteCustomization < ActiveRecord::Migration
  def change
    remove_column :site_customizations, :position
  end
end
