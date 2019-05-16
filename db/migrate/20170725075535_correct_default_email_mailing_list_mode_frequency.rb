# frozen_string_literal: true

class CorrectDefaultEmailMailingListModeFrequency < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE site_settings SET value = '1' WHERE value = '0' AND name = 'default_email_mailing_list_mode_frequency';"
  end

  def down
  end
end
