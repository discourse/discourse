class AddTopicCustomFields < ActiveRecord::Migration
  def change
    create_table :topic_custom_fields do |t|
      t.integer :topic_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps
    end

    add_index :topic_custom_fields, [:topic_id, :name]

    # migrate meta_data into custom fields
    execute <<-SQL
      INSERT INTO topic_custom_fields(topic_id, name, value)
        SELECT id, (each(meta_data)).key, (each(meta_data)).value
            FROM topics WHERE meta_data <> ''
    SQL

    remove_column :topics, :meta_data
  end
end
