class CreateTags < ActiveRecord::Migration[4.2]
  def change
    create_table :tags do |t|
      t.string      :name,        null: false
      t.integer     :topic_count, null: false, default: 0
      t.timestamps null: false
    end

    create_table :topic_tags do |t|
      t.references :topic, null: false
      t.references :tag,   null: false
      t.timestamps null: false
    end

    create_table :tag_users do |t|
      t.references :tag,  null: false
      t.references :user, null: false
      t.integer    :notification_level, null: false
      t.timestamps null: false
    end

    add_index :tags, :name, unique: true
    add_index :topic_tags, [:topic_id, :tag_id], unique: true
    add_index :tag_users, [:user_id, :tag_id, :notification_level], name: "idx_tag_users_ix1", unique: true
    add_index :tag_users, [:tag_id, :user_id, :notification_level], name: "idx_tag_users_ix2", unique: true
  end
end
