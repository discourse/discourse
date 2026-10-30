# frozen_string_literal: true

class CreateDiscourseBlogPublications < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_blog_publications do |table|
      table.bigint :topic_id, null: false
      table.bigint :publisher_id
      table.string :path, null: false
      table.string :excerpt, null: false, default: ""
      table.boolean :featured, null: false, default: false
      table.boolean :published, null: false, default: false
      table.datetime :published_at
      table.timestamps
    end
    add_index :discourse_blog_publications, :topic_id, unique: true
    add_index :discourse_blog_publications, %i[published published_at]

    create_table :discourse_blog_paths do |table|
      table.bigint :publication_id, null: false
      table.string :path, null: false
      table.timestamps
    end
    add_index :discourse_blog_paths, :path, unique: true
    add_index :discourse_blog_paths, :publication_id
  end
end
