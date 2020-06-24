# frozen_string_literal: true

class AddReadOnlyToCategories < ActiveRecord::Migration[6.0]
  def change
    add_column :categories, :read_only_banner, :string
  end
end
