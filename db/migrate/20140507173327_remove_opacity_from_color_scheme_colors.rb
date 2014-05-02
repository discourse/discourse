class RemoveOpacityFromColorSchemeColors < ActiveRecord::Migration
  def up
    remove_column :color_scheme_colors, :opacity
  end

  def down
    add_column :color_scheme_colors, :opacity, :integer, null: false, default: 100
  end
end
