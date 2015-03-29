class RemoveColorHexcodeFromBadgeTypes < ActiveRecord::Migration
  def change
    remove_column :badge_types, :color_hexcode, :string
  end
end
