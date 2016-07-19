class AddCompilerVersionToSiteCustomizations < ActiveRecord::Migration
  def change
    add_column :site_customizations, :compiler_version, :integer, default: 0, null: false
  end
end
