class AddWhisperSupportToTopics < ActiveRecord::Migration[4.2]
  def up
    remove_column :topics, :bookmark_count
    remove_column :topics, :off_topic_count
    remove_column :topics, :illegal_count
    remove_column :topics, :inappropriate_count
    remove_column :topics, :notify_user_count

    add_column :topics, :highest_staff_post_number, :int, default: 0, null: false
    execute "UPDATE topics SET highest_staff_post_number = highest_post_number"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
