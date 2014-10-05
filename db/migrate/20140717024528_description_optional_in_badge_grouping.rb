class DescriptionOptionalInBadgeGrouping < ActiveRecord::Migration
  def change
    change_column :badge_groupings, :description, :text, null: true
  end
end
