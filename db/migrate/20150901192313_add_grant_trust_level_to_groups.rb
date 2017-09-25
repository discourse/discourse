class AddGrantTrustLevelToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :grant_trust_level, :integer
  end
end
