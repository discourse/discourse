class RemoveAccessPassword < ActiveRecord::Migration
  def up
    result = execute("SELECT count(*) FROM site_settings where name='access_password' and char_length(value) > 0")
    if result[0] and result[0]["count"].to_i > 0
      execute "DELETE FROM site_settings where name='access_password'"
      SiteSetting.login_required = true
      SiteSetting.must_approve_users = true
    end
  end

  def down
    # Don't undo
  end
end
