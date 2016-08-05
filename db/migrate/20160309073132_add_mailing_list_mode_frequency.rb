class AddMailingListModeFrequency < ActiveRecord::Migration
  def change
    add_column :user_options, :mailing_list_mode_frequency, :integer, default: 0, null: false
  end
end
