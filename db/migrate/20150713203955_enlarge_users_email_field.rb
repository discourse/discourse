# frozen_string_literal: true

class EnlargeUsersEmailField < ActiveRecord::Migration[4.2]
  def up
    change_column :users, :email, :string, limit: 513
  end
  def down
    change_column :users, :email, :string, limit: 128
  end
end
