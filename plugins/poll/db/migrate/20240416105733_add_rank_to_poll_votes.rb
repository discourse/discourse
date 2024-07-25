# frozen_string_literal: true

class AddRankToPollVotes < ActiveRecord::Migration[7.0]
  def change
    add_column :poll_votes, :rank, :integer, null: false, default: 0
  end
end
