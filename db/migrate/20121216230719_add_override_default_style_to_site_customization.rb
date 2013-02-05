class AddOverrideDefaultStyleToSiteCustomization < ActiveRecord::Migration
  def change
    add_column :site_customizations, :override_default_style, :boolean, default: false, null: false
    add_column :site_customizations, :stylesheet_baked, :text, default: '', null: false
  end
end
