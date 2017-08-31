class AddAutomaticallyUnpinTopicsToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :automatically_unpin_topics, :boolean, nullabe: false, default: true
  end
end
