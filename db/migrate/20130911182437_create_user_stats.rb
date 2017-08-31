class CreateUserStats < ActiveRecord::Migration[4.2]
  def up
    create_table :user_stats, id: false do |t|
      t.references :user, null: false
      t.boolean :has_custom_avatar, default: false, null: false
    end
    execute "ALTER TABLE user_stats ADD PRIMARY KEY (user_id)"
    execute "INSERT INTO user_stats (user_id) SELECT id FROM users"
  end

  def down
    drop_table :user_stats
  end

end
