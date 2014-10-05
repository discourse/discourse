class AddMultipleAwardToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :multiple_grant, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        remove_index :user_badges, column: [:badge_id, :user_id]
        add_index :user_badges, [:badge_id, :user_id]
      end

      dir.down do
        remove_index :user_badges, column: [:badge_id, :user_id]
        add_index :user_badges, [:badge_id, :user_id], unique: true
      end
    end
  end
end
