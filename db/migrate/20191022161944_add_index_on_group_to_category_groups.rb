# frozen_string_literal: true

class AddIndexOnGroupToCategoryGroups < ActiveRecord::Migration[6.0]
  def change
    add_index :category_groups, :group_id
  end
end
