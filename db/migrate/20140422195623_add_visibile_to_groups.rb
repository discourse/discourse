# frozen_string_literal: true

class AddVisibileToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :visible, :boolean, default: true, null: false
  end
end
