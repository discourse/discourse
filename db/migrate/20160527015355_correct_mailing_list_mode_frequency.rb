class CorrectMailingListModeFrequency < ActiveRecord::Migration[4.2]
  def up
    # historically mailing list mode was for every message
    # keep working the same way for all old users
    execute 'UPDATE user_options SET mailing_list_mode_frequency = 1 where mailing_list_mode'
  end

  def down
  end
end
