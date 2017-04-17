class RenameThemeId < ActiveRecord::Migration
  def change
    rename_column :color_schemes, :theme_id, :base_scheme_id
  end
end
