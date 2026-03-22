# frozen_string_literal: true

class DeleteRedundantEveryonePostingReviewGroups < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      DELETE FROM category_posting_review_groups
      WHERE group_id = 0 AND permission = 1
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
