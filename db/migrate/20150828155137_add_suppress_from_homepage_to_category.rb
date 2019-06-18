# frozen_string_literal: true

class AddSuppressFromHomepageToCategory < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :suppress_from_homepage, :boolean, default: false
  end
end
