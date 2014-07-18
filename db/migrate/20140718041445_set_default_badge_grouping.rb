class SetDefaultBadgeGrouping < ActiveRecord::Migration
  def change
    change_column :badges, :badge_grouping_id, :integer, null: false, default: 5
  end
end
