class AddThemeIdToColorScheme < ActiveRecord::Migration
  def change
    add_column :color_schemes, :theme_id, :int
  end
end
