# frozen_string_literal: true

class RemoveOverrideDefaultStylesFromSiteCustomizations < ActiveRecord::Migration[4.2]
  def change
    remove_column :site_customizations, :override_default_style
  end
end
