# frozen_string_literal: true

class AddNotifyOnSolvedToUserOptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :notify_on_solved, :boolean, default: true, null: false
  end
end
