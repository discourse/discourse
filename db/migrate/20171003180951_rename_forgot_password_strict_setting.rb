# frozen_string_literal: true

class RenameForgotPasswordStrictSetting < ActiveRecord::Migration[5.1]
  def up
    execute "UPDATE site_settings SET name = 'hide_email_address_taken' WHERE name = 'forgot_password_strict'"
  end

  def down
    execute "UPDATE site_settings SET name = 'forgot_password_strict' WHERE name = 'hide_email_address_taken'"
  end
end
