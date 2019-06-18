# frozen_string_literal: true

class RemoveCategoryHotness < ActiveRecord::Migration[4.2]
  def change
    remove_column :categories, :hotness
  end
end
