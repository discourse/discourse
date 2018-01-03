class AddDisagreedAtAndDisagreedByIdToPostAction < ActiveRecord::Migration[4.2]
  def up
    add_column :post_actions, :disagreed_at, :datetime
    add_column :post_actions, :disagreed_by_id, :integer

    execute <<-SQL
      UPDATE post_actions
         SET disagreed_at = deleted_at,
             disagreed_by_id = deleted_by_id,
             deleted_at = NULL,
             deleted_by_id = NULL
       WHERE deleted_by_id != user_id
    SQL
  end

  def down
    execute <<-SQL
      UPDATE post_actions
         SET deleted_at = disagreed_at,
             deleted_by_id = disagreed_by_id
       WHERE disagreed_by_id != user_id
    SQL

    remove_column :post_actions, :disagreed_at
    remove_column :post_actions, :disagreed_by_id
  end
end
