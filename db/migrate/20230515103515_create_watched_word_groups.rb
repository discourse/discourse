# frozen_string_literal: true

class CreateWatchedWordGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :watched_word_groups do |t|
      t.integer :action, null: false

      t.timestamps
    end
  end
end
