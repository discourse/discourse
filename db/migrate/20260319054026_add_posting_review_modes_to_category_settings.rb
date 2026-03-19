# frozen_string_literal: true

class AddPostingReviewModesToCategorySettings < ActiveRecord::Migration[8.0]
  def up
    add_column :category_settings, :topic_posting_review_mode, :integer, default: 0, null: false
    add_column :category_settings, :reply_posting_review_mode, :integer, default: 0, null: false

    # Backfill: for categories that had everyone-group (id 0) rows with
    # permission = required (1), set the posting review mode to everyone (1).

    # Topics (post_type = 0)
    execute(<<~SQL)
      UPDATE category_settings
      SET topic_posting_review_mode = 1
      WHERE category_id IN (
        SELECT category_id FROM category_posting_review_groups
        WHERE group_id = 0 AND permission = 1 AND post_type = 0
      )
    SQL

    # Replies (post_type = 1)
    execute(<<~SQL)
      UPDATE category_settings
      SET reply_posting_review_mode = 1
      WHERE category_id IN (
        SELECT category_id FROM category_posting_review_groups
        WHERE group_id = 0 AND permission = 1 AND post_type = 1
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
