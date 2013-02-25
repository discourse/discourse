class RemoveTrustLevels < ActiveRecord::Migration
  def up
    drop_table :trust_levels
    change_column_default :users, :trust_level_id, TrustLevel.Levels[:new]
    rename_column :users, :trust_level_id, :trust_level

    update "UPDATE users set trust_level = #{TrustLevel.Levels[:regular]}"
    update "UPDATE users set trust_level = #{TrustLevel.Levels[:moderator]} where moderator = true"

    remove_column :users, :moderator
    add_column :users, :flag_level, :integer, null: false, default: 0
  end

end
