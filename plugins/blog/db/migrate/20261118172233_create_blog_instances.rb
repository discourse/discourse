# frozen_string_literal: true
class CreateBlogInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :blog_instances do |t|
      t.string :name, null: false
      t.text :description, null: false, default: ""
      t.text :about, null: false, default: ""
      t.string :slug, null: false
      t.string :url
      t.integer :category_id
      t.string :path_format, null: false, default: "/{slug}"
      t.integer :posts_per_page, null: false, default: 10
      t.jsonb :active_theme
      t.boolean :is_default, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :blog_instances, :slug, unique: true
    add_index :blog_instances, :url, unique: true
    add_index :blog_instances, :category_id, unique: true
    add_index :blog_instances, :is_default, unique: true, where: "is_default"
  end
end
