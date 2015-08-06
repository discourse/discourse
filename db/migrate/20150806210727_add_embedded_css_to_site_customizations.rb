class AddEmbeddedCssToSiteCustomizations < ActiveRecord::Migration
  def change
    add_column :site_customizations, :embedded_css, :text
    add_column :site_customizations, :embedded_css_baked, :text
  end
end
