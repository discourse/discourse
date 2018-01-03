class RenameThemeId < ActiveRecord::Migration[4.2]
  def change
    rename_column :color_schemes, :theme_id, :base_scheme_id
  end
end
