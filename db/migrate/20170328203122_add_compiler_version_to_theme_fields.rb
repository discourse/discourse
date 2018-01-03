class AddCompilerVersionToThemeFields < ActiveRecord::Migration[4.2]
  def change
    add_column :theme_fields, :compiler_version, :integer, null: false, default: 0
  end
end
