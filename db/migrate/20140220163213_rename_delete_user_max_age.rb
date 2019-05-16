# frozen_string_literal: true

class RenameDeleteUserMaxAge < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE site_settings SET name = 'delete_user_max_post_age' WHERE name = 'delete_user_max_age'"
  end
end
