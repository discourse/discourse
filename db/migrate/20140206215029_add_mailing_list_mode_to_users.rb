class AddMailingListModeToUsers < ActiveRecord::Migration[4.2]
  def change
    rename_column :users, :watch_new_topics, :mailing_list_mode
  end
end
