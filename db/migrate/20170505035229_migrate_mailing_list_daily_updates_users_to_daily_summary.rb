class MigrateMailingListDailyUpdatesUsersToDailySummary < ActiveRecord::Migration
  def change
    change_column_default :user_options, :mailing_list_mode_frequency, 1

    UserOption.exec_sql(<<~SQL)
    UPDATE user_options
    SET digest_after_minutes = 1440, email_digests = 't', mailing_list_mode = 'f'
    WHERE mailing_list_mode_frequency = 0 AND mailing_list_mode
    SQL
  end
end
