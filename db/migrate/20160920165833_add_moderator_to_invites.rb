class AddModeratorToInvites < ActiveRecord::Migration
  def change
    add_column :invites, :moderator, :boolean, default: false, null: false
  end
end
