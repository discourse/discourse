class CreateDigestUnsubscribeKeys < ActiveRecord::Migration[4.2]
  def up
    create_table :digest_unsubscribe_keys, id: false do |t|
      t.string :key, limit: 64, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end
    execute "ALTER TABLE digest_unsubscribe_keys ADD PRIMARY KEY (key)"
    add_index :digest_unsubscribe_keys, :created_at

    migrate_redis_keys
  end

  # It is slightly odd to migrate from redis to postgres; I imagine a lot
  # could fail, so if anything does we just rescue
  def migrate_redis_keys
    return if Rails.env.test?

    temp_keys = $redis.keys('temporary_key:*')
    if temp_keys.present?
      temp_keys.map! do |key|
        user_id = $redis.get(key).to_i
        ttl = $redis.ttl(key).to_i

        if ttl > 0
          ttl = "'#{ttl.seconds.ago.strftime('%Y-%m-%d %H:%M:%S')}'"
        else
          ttl = "CURRENT_TIMESTAMP"
        end
        $redis.del(key)
        key.gsub!('temporary_key:', '')
        user_id ? "('#{key}', #{user_id}, #{ttl}, #{ttl})" : nil
      end
      temp_keys.compact!
      if temp_keys.present?
        execute "INSERT INTO digest_unsubscribe_keys (key, user_id, created_at, updated_at) VALUES #{temp_keys.join(', ')}"
      end
    end
  rescue
    # If anything goes wrong, continue with other migrations
  end

  def down
    drop_table :digest_unsubscribe_keys
  end
end
