# frozen_string_literal: true
class AddWatchedPrecedenceOverMutedToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :watched_precedence_over_muted, :boolean
  end
end
