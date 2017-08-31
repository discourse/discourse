class NormalizeTopicViewDataAndIndex < ActiveRecord::Migration[4.2]
  def change
    remove_index :topic_views, [:topic_id]
    remove_index :topic_views, [:user_id, :topic_id]

    execute 'CREATE TEMPORARY TABLE tmp_views_user(user_id int, topic_id int, viewed_at date, ip_address inet)'

    execute 'INSERT INTO tmp_views_user(user_id, topic_id, ip_address, viewed_at)
      SELECT user_id, topic_id, min(ip_address::varchar)::inet, min(viewed_at)
      FROM topic_views
      WHERE user_id IS NOT NULL
      GROUP BY user_id, topic_id
    '

    execute 'CREATE TEMPORARY TABLE tmp_views_ip(topic_id int, viewed_at date, ip_address inet)'

    execute 'INSERT INTO tmp_views_ip(topic_id, ip_address, viewed_at)
      SELECT topic_id, ip_address, min(viewed_at)
      FROM topic_views
      WHERE user_id IS NULL
      GROUP BY user_id, topic_id, ip_address
    '

    execute 'truncate table topic_views'

    execute 'INSERT INTO topic_views(user_id, topic_id, ip_address, viewed_at)
    SELECT user_id, topic_id, ip_address, viewed_at FROM tmp_views_user
    UNION ALL
    SELECT NULL, topic_id, ip_address, viewed_at FROM tmp_views_ip
    '

    execute 'CREATE UNIQUE INDEX user_id_topic_id_topic_views ON topic_views(user_id, topic_id) WHERE user_id IS NOT NULL'
    execute 'CREATE UNIQUE INDEX ip_address_topic_id_topic_views ON topic_views(ip_address, topic_id) WHERE user_id IS NULL'

    add_index :topic_views, [:topic_id, :viewed_at]
    add_index :topic_views, [:viewed_at, :topic_id]
  end
end
