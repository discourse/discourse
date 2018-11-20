class AddVisibilityLevelToGroups < ActiveRecord::Migration[4.2]
  def change

    add_column :groups, :visibility_level, :integer, default: 0, null: false
    execute <<~SQL
      UPDATE groups
      SET visibility_level = 1
      WHERE NOT visible
    SQL
    remove_column :groups, :visible
  end
end
