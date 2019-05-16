# frozen_string_literal: true

class DisableInviteOnlySso < ActiveRecord::Migration[5.2]
  def up
    execute(<<~SQL)
      UPDATE site_settings SET value = 'f'
      WHERE name = 'invite_only'
        AND EXISTS(SELECT 1 FROM site_settings WHERE name = 'enable_sso' AND value = 't')
    SQL
  end
end
