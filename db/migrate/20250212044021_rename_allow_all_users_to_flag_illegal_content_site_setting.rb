# frozen_string_literal: true
class RenameAllowAllUsersToFlagIllegalContentSiteSetting < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE site_settings SET name = 'allow_all_users_to_flag_illegal_content' where name = 'allow_tl0_and_anonymous_users_to_flag_illegal_content'"
  end

  def down
    execute "UPDATE site_settings SET name = 'allow_tl0_and_anonymous_users_to_flag_illegal_content' where name = 'allow_all_users_to_flag_illegal_content'"
  end
end
