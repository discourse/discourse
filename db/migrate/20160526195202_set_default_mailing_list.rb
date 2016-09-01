class SetDefaultMailingList < ActiveRecord::Migration
  def change
    change_column_default :user_options, :mailing_list_mode_frequency, 1
  end
end
