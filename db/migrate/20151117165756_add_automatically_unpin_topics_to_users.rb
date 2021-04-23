# frozen_string_literal: true

class AddAutomaticallyUnpinTopicsToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :automatically_unpin_topics, :boolean, null: false, default: true
  end
end
