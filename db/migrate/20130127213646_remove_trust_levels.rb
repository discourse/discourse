# frozen_string_literal: true

class RemoveTrustLevels < ActiveRecord::Migration[4.2]
  def up
    drop_table :trust_levels
    change_column_default :users, :trust_level_id, TrustLevel[0]
    rename_column :users, :trust_level_id, :trust_level

    update "UPDATE users set trust_level = 1"

    remove_column :users, :moderator
    add_column :users, :flag_level, :integer, null: false, default: 0
  end

end
