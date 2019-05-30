# frozen_string_literal: true

class AddIndexPostActionTypeIdDisagreedAtOnPostActions < ActiveRecord::Migration[5.2]
  def change
    add_index :post_actions, [:post_action_type_id, :disagreed_at],
      where: "(disagreed_at IS NULL)"
  end
end
