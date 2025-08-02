# frozen_string_literal: true

class AmendSiteCustomization < ActiveRecord::Migration[4.2]
  def change
    remove_column :site_customizations, :position
  end
end
