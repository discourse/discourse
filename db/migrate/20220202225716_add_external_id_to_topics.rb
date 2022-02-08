# frozen_string_literal: true

class AddExternalIdToTopics < ActiveRecord::Migration[6.1]
  def change
    add_column :topics, :external_id, :string, null: true
    add_index :topics, :external_id, unique: true, where: 'external_id IS NOT NULL'
  end
end
