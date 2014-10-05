class SetDefaultBadgeGrouping < ActiveRecord::Migration
  def change
    execute 'UPDATE badges SET badge_grouping_id = 5 WHERE badge_grouping_id IS NULL'
    change_column :badges, :badge_grouping_id, :integer, null: false, default: 5
  end
end
