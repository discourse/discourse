class RemoveTrustLevels < ActiveRecord::Migration
  def up
    drop_table :trust_levels
    change_column_default :users, :trust_level_id, TrustLevel.levels[:new]
    rename_column :users, :trust_level_id, :trust_level

    update "UPDATE users set trust_level = #{TrustLevel.levels[:regular]}"
    update "UPDATE users set trust_level = #{TrustLevel.levels[:moderator]} where moderator = true"

    remove_column :users, :moderator
    add_column :users, :flag_level, :integer, null: false, default: 0
  end

end
