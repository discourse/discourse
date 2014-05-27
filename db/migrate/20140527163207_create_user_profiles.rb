class CreateUserProfiles < ActiveRecord::Migration
  def up
    create_table :user_profiles, id: false do |t|
      t.references :user
      t.string :location
    end
    execute "ALTER TABLE user_profiles ADD PRIMARY KEY (user_id)"
    execute "INSERT INTO user_profiles (user_id) SELECT id FROM users"
  end

  def down
    drop_table :user_profiles
  end
end
