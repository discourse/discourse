# frozen_string_literal: true
class CreateDirectoryColumns < ActiveRecord::Migration[6.1]
  def up
    create_table :directory_columns do |t|
      t.string :name, null: true
      t.integer :automatic_position, null: true
      t.string :icon, null: true
      t.integer :user_field_id, null: true
      t.boolean :automatic, null: false
      t.boolean :enabled, null: false
      t.integer :position, null: false
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :directory_columns, %i[enabled position user_field_id], name: "directory_column_index"

    create_automatic_columns
  end

  def down
    drop_table :directory_columns
  end

  def create_automatic_columns
    DB.exec(<<~SQL)
      INSERT INTO directory_columns (
        name, automatic, enabled, automatic_position, position, icon
      )
      VALUES
        ( 'likes_received', true, true, 1, 1, 'heart' ),
        ( 'likes_given', true, true, 2, 2, 'heart' ),
        ( 'topic_count', true, true, 3, 3, NULL ),
        ( 'post_count', true, true, 4, 4, NULL ),
        ( 'topics_entered', true, true, 5, 5, NULL ),
        ( 'posts_read', true, true, 6, 6, NULL ),
        ( 'days_visited', true, true, 7, 7, NULL );
      SQL
  end
end
