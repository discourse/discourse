class AddSiteIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :site_id, :integer
    add_column :users, :bio, :text

    add_index :users, :site_id
    execute "UPDATE users SET site_id = 1"
  end
end
