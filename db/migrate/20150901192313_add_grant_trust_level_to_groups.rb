class AddGrantTrustLevelToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :grant_trust_level, :integer
  end
end
