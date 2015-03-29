class AddInvitedGroups < ActiveRecord::Migration
  def change
    create_table :invited_groups do |t|
      t.integer :group_id
      t.integer :invite_id
      t.timestamps
    end
  end
end
