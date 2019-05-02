# frozen_string_literal: true

class AddOverrideDefaultStyleToSiteCustomization < ActiveRecord::Migration[4.2]
  def change
    add_column :site_customizations, :override_default_style, :boolean, default: false, null: false
    add_column :site_customizations, :stylesheet_baked, :text, default: '', null: false
  end
end
