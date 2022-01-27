# frozen_string_literal: true

class AddDescriptionToTags < ActiveRecord::Migration[6.1]
  def change
    add_column :tags, :description, :string
  end
end
