# frozen_string_literal: true

class AddQuoteCountToPosts < ActiveRecord::Migration[4.2]
  def up
    add_column :posts, :quote_count, :integer, default: 0, null: false
    execute "UPDATE posts SET quote_count = 1 WHERE quoteless = 'f'"
    remove_column :posts, :quoteless
  end

  def down
    remove_column :posts, :quote_count
    add_column :posts, :quoteless, :boolean, default: false
  end
end
