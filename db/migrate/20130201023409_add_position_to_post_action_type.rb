class AddPositionToPostActionType < ActiveRecord::Migration
  def change
    add_column :post_action_types, :position, :integer, default: 0, null: false
  end
end
