class AddAdminOnlyToUserHistories < ActiveRecord::Migration
  def up
    add_column :user_histories, :admin_only, :boolean, default: false
    execute "UPDATE user_histories SET admin_only = true WHERE action = #{UserHistory.actions[:change_site_setting]}"
  end

  def down
    remove_column :user_histories, :admin_only
  end
end
