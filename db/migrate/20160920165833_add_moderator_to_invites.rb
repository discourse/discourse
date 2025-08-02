# frozen_string_literal: true

class AddModeratorToInvites < ActiveRecord::Migration[4.2]
  def change
    add_column :invites, :moderator, :boolean, default: false, null: false
  end
end
