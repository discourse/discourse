# frozen_string_literal: true

class MigrateForwardedEmailsBehaviourSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name      = 'forwarded_emails_behaviour',
          data_type = 7,
          value     = 'create_replies'
      WHERE name = 'enable_forwarded_emails' AND value = 't';
    SQL

    execute <<~SQL
      DELETE
      FROM site_settings
      WHERE name = 'enable_forwarded_emails';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET name      = 'enable_forwarded_emails',
          data_type = 5,
          value     = 't'
      WHERE name = 'forwarded_emails_behaviour' AND value = 'create_replies';
    SQL

    execute <<~SQL
      DELETE
      FROM site_settings
      WHERE name = 'forwarded_emails_behaviour';
    SQL
  end
end
