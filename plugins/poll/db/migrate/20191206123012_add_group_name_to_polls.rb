# frozen_string_literal: true

class AddGroupNameToPolls < ActiveRecord::Migration[5.2]
  def change
    add_column :polls, :groups, :string
  end
end
