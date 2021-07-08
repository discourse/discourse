# frozen_string_literal: true

class AddFlairGroupIdToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :flair_group_id, :integer, null: true
  end
end
