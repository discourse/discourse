# frozen_string_literal: true

class AddWordCountToPosts < ActiveRecord::Migration[4.2]
  def up
    add_column :posts, :word_count, :integer
    add_column :topics, :word_count, :integer
  end

  def down
    remove_column :posts, :word_count, :integer
    remove_column :topics, :word_count, :integer
  end
end
