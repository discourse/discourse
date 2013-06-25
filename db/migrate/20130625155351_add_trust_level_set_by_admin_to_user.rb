class AddTrustLevelSetByAdminToUser < ActiveRecord::Migration
  def change
    add_column :users, :trust_level_set_by_admin, :boolean, :default => false
  end
end
