class AddMailingListModeToUsers < ActiveRecord::Migration
  def change
    rename_column :users, :watch_new_topics, :mailing_list_mode
  end
end
