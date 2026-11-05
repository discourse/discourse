# frozen_string_literal: true

# Promoted from a post-deploy migration so the drop runs before
# RenameDiscourseBlogToBlog turns discourse_blog_reviews into a view.
class DropBlogReviewTokenDigest < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { discourse_blog_reviews: %i[token_digest] }

  def up
    Migration::SafeMigrate.disable!
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
