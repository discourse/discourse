class AddUniqIpOrUserIdTopicViews < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    unless index_exists?(:topic_views, [:user_id, :ip_address, :topic_id],
      name: :uniq_ip_or_user_id_topic_views
    )

      add_index :topic_views, [:user_id, :ip_address, :topic_id],
        name: :uniq_ip_or_user_id_topic_views,
        unique: true,
        algorithm: :concurrently
    end
  end
end
