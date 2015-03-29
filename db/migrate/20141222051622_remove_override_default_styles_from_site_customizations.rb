class RemoveOverrideDefaultStylesFromSiteCustomizations < ActiveRecord::Migration
  def change
    remove_column :site_customizations, :override_default_style
  end
end
