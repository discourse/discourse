class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do |t|
      t.string      :name,        null: false
      t.integer     :topic_count, null: false, default: 0
      t.timestamps
    end

    create_table :topic_tags do |t|
      t.references :topic, null: false
      t.references :tag,   null: false
      t.timestamps
    end

    add_index :tags, :name, unique: true
    add_index :topic_tags, [:topic_id, :tag_id], unique: true

    # tag_users? for notification preferences
  end
end
