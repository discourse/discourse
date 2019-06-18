# frozen_string_literal: true

class AddActionCodeToPost < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :action_code, :string, null: true
  end
end
