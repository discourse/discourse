# frozen_string_literal: true

class AddUserIdToIncomingLinks < ActiveRecord::Migration[4.2]
  def change
    add_column :incoming_links, :user_id, :integer
  end
end
