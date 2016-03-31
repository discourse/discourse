class AllowDefaultsOnUsersTable < ActiveRecord::Migration
  def up
    # we need to temporarily change table a bit to ensure we can insert new records
    change_column :users, :email_digests, :boolean, null: false, default: true
    change_column :users, :external_links_in_new_tab, :boolean, null: false, default: false
  end

  def down
  end
end
