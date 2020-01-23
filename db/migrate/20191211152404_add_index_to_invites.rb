# frozen_string_literal: true

class AddIndexToInvites < ActiveRecord::Migration[6.0]
  def change
    add_index :invites, [:invited_by_id]
  end
end
