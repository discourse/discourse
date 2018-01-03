class RenameActionsToUserActions < ActiveRecord::Migration[4.2]
  def change
    rename_table 'actions', 'user_actions'
  end
end
