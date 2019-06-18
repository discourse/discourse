# frozen_string_literal: true

class RemoveTagCountFromTagGroups < ActiveRecord::Migration[4.2]
  def change
    remove_column :tag_groups, :tag_count
  end
end
