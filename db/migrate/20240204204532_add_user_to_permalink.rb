# frozen_string_literal: true

class AddUserToPermalink < ActiveRecord::Migration[7.0]
  def change
    add_column :permalinks, :user_id, :integer
  end
end
