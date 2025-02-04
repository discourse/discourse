# frozen_string_literal: true

class RenameFullPageSiteSetting < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE site_settings SET name = 'full_page_login' where name = 'experimental_full_page_login'"
  end

  def down
    execute "UPDATE site_settings SET name = 'experimental_full_page_login' where name = 'full_page_login'"
  end
end
