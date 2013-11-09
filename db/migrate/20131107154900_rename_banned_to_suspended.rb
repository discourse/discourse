class RenameBannedToSuspended < ActiveRecord::Migration
  def change
    rename_column :users, :banned_at,   :suspended_at
    rename_column :users, :banned_till, :suspended_till
  end
end
