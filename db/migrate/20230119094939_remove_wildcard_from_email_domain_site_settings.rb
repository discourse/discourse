# frozen_string_literal: true

class RemoveWildcardFromEmailDomainSiteSettings < ActiveRecord::Migration[7.0]
  def up
    execute <<~'SQL'
      UPDATE site_settings
      SET value = regexp_replace(value, '\*(\.)?|\?', '', 'g')
      WHERE name IN (
        'auto_approve_email_domains',
        'allowed_email_domains',
        'blocked_email_domains'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
