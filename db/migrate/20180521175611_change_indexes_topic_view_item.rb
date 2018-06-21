class ChangeIndexesTopicViewItem < ActiveRecord::Migration[5.1]
  def up
    begin
      Migration::SafeMigrate.disable!
      change_column :topic_views, :ip_address, :inet, null: true
    ensure
      Migration::SafeMigrate.enable!
    end

    remove_index :topic_views,
      column: [:ip_address, :topic_id],
      name: :ip_address_topic_id_topic_views,
      unique: true
    remove_index :topic_views,
      column: [:user_id, :topic_id],
      name: :user_id_topic_id_topic_views,
      unique: true
    add_index :topic_views, [:user_id, :ip_address, :topic_id],
      name: :uniq_ip_or_user_id_topic_views,
      unique: true
  end

  def down
  end
end
