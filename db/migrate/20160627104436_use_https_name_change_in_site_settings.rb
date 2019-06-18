# frozen_string_literal: true

class UseHttpsNameChangeInSiteSettings < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE site_settings SET name = 'force_https' WHERE name = 'use_https'"
  end
end
