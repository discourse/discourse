class AddBakedHeadAndBodyToSiteCustomizations < ActiveRecord::Migration[4.2]
  def change
    add_column :site_customizations, :head_tag_baked, :text
    add_column :site_customizations, :body_tag_baked, :text
  end
end
