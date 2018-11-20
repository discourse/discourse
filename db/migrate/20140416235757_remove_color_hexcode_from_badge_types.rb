class RemoveColorHexcodeFromBadgeTypes < ActiveRecord::Migration[4.2]
  def change
    remove_column :badge_types, :color_hexcode, :string
  end
end
