class AddCompilerVersionToThemeFields < ActiveRecord::Migration
  def change
    add_column :theme_fields, :compiler_version, :integer, null: false, default: 0
  end
end
