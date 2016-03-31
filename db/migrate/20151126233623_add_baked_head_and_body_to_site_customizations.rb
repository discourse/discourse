class AddBakedHeadAndBodyToSiteCustomizations < ActiveRecord::Migration
  def change
    add_column :site_customizations, :head_tag_baked, :text
    add_column :site_customizations, :body_tag_baked, :text
  end
end
