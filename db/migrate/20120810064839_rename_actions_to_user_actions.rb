class RenameActionsToUserActions < ActiveRecord::Migration
  def change
    rename_table 'actions', 'user_actions'
  end
end
