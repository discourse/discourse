# frozen_string_literal: true

class DropBlogReviewTokenDigest < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { discourse_blog_reviews: %i[token_digest] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
