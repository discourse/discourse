class AddSequenceToPostActionTypes < ActiveRecord::Migration
  def change
    remove_column :post_action_types, :id
    add_column :post_action_types, :id, :primary_key
  end
end
