# frozen_string_literal: true

class AlterPostVotingIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :post_voting_comment_custom_fields, :post_voting_comment_id, :bigint
    change_column :post_voting_votes, :votable_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
