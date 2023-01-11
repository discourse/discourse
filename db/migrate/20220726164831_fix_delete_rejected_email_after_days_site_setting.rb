# frozen_string_literal: true
class FixDeleteRejectedEmailAfterDaysSiteSetting < ActiveRecord::Migration[6.1]
  def up
    delete_rejected_email_after_days =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'delete_rejected_email_after_days'",
      ).first
    delete_email_logs_after_days =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'delete_email_logs_after_days'",
      ).first

    # These settings via the sql query return nil if they are using their default values
    unless delete_email_logs_after_days
      delete_email_logs_after_days = DeleteRejectedEmailAfterDaysValidator::MAX
    end

    # Only update if the setting is not using the default and it is lower than 'delete_email_logs_after_days'
    if delete_rejected_email_after_days != nil &&
         delete_rejected_email_after_days.to_i < delete_email_logs_after_days.to_i
      execute <<~SQL
      UPDATE site_settings
      SET value = #{delete_email_logs_after_days.to_i}
      WHERE name = 'delete_rejected_email_after_days'
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
