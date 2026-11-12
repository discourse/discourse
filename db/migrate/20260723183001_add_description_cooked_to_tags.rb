# frozen_string_literal: true

class AddDescriptionCookedToTags < ActiveRecord::Migration[8.0]
  def change
    add_column :tags, :description_cooked, :string, limit: 2000
    add_column :tags, :description_cooked_version, :integer
    add_column :tag_localizations, :description_cooked, :string, limit: 2000
    add_column :tag_localizations, :description_cooked_version, :integer
    add_index :tags, :description_cooked_version
    add_index :tag_localizations, :description_cooked_version
  end
end
