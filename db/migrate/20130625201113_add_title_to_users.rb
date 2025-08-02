# frozen_string_literal: true

class AddTitleToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :title, :string
  end
end
