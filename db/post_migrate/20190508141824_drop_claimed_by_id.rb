# frozen_string_literal: true

class DropClaimedById < ActiveRecord::Migration[5.2]
  def up
    remove_column :reviewables, :claimed_by_id
  end
end
