# frozen_string_literal: true

class AddCompilerVersionToSiteCustomizations < ActiveRecord::Migration[4.2]
  def change
    add_column :site_customizations, :compiler_version, :integer, default: 0, null: false
  end
end
