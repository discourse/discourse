class AddWatchNewTopicsToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :watch_new_topics, :boolean, default: false, null: false
  end
end
