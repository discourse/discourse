class RenameWarnings < ActiveRecord::Migration
  def up
    rename_table :warnings, :user_warnings
  end

  def down
    rename_table :user_warnings, :warnings
  end
end
