# frozen_string_literal: true

class AddTitleToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :title, :string
  end
end
