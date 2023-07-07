# frozen_string_literal: true

class AddWatchedPrecedenceOverMutedIndexToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_index :user_options, :watched_precedence_over_muted
  end
end
