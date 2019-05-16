# frozen_string_literal: true

class FixIndexOnPostActions < ActiveRecord::Migration[4.2]
  def change
    execute 'UPDATE post_actions SET targets_topic = false WHERE targets_topic IS NULL'
    change_column :post_actions, :targets_topic, :boolean, default: false, null: false

    execute '
    DELETE FROM post_actions pa
                    USING post_actions x
    WHERE pa.user_id = x.user_id AND
          pa.post_action_type_id = x.post_action_type_id AND
          pa.post_id = x.post_id AND
          pa.targets_topic = x.targets_topic AND
          pa.id < x.id AND
          pa.deleted_at IS NULL AND
          x.deleted_at IS NULL
    '

    remove_index "post_actions", name: "idx_unique_actions"
    add_index "post_actions",
                ["user_id", "post_action_type_id",
                 "post_id", "targets_topic"],
                name: "idx_unique_actions",
                unique: true,
                where: 'deleted_at IS NULL'
  end
end
