# frozen_string_literal: true

class AddTitleToPolls < ActiveRecord::Migration[6.0]
  def change
    add_column :polls, :title, :string
  end
end
