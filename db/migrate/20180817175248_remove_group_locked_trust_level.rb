class RemoveGroupLockedTrustLevel < ActiveRecord::Migration[5.2]
  def change
    remove_column :users, :group_locked_trust_level
  end
end
