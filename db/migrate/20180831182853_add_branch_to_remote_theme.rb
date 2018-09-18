class AddBranchToRemoteTheme < ActiveRecord::Migration[5.2]
  def change
    add_column :remote_themes, :branch, :string
  end
end
