# frozen_string_literal: true

class RenameDigestAfterDaysToDigestAfterMinutes < ActiveRecord::Migration[4.2]
  def up
    rename_column :user_options, :digest_after_days, :digest_after_minutes
    execute "UPDATE user_options SET digest_after_minutes = digest_after_minutes * 1440 WHERE digest_after_minutes IS NOT NULL"
    execute "UPDATE site_settings SET value = value::integer * 1440 WHERE name = 'default_email_digest_frequency' AND value IS NOT NULL"
  end

  def down
    rename_column :user_options, :digest_after_minutes, :digest_after_days
    execute "UPDATE user_options SET digest_after_days = digest_after_days / 1440 WHERE digest_after_days IS NOT NULL"
    execute "UPDATE site_settings SET value = value::integer / 1440 WHERE name = 'default_email_digest_frequency' AND value IS NOT NULL"
  end
end
