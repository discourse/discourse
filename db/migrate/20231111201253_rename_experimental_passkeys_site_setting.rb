# frozen_string_literal: true

class RenameExperimentalPasskeysSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE site_settings SET name = 'enable_passkeys' WHERE name = 'experimental_passkeys'"
  end

  def down
    execute "UPDATE site_settings SET name = 'experimental_passkeys' WHERE name = 'enable_passkeys'"
  end
end
