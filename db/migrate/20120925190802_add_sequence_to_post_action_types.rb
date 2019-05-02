# frozen_string_literal: true

class AddSequenceToPostActionTypes < ActiveRecord::Migration[4.2]
  def change
    remove_column :post_action_types, :id
    add_column :post_action_types, :id, :primary_key
  end
end
