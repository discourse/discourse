# frozen_string_literal: true

class IndexTopicsForFrontPage < ActiveRecord::Migration[4.2]
  def change
    add_index :topics, %i[deleted_at visible archetype id]
    # covering index for join
    add_index :topics, %i[id deleted_at]
  end
end
