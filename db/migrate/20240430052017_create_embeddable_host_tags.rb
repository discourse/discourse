# frozen_string_literal: true
class CreateEmbeddableHostTags < ActiveRecord::Migration[7.0]
  def change
    create_table :embeddable_host_tags do |t|
      t.integer :embeddable_host_id, null: false
      t.integer :tag_id, null: false

      t.timestamps
    end

    add_index :embeddable_host_tags, :embeddable_host_id
    add_index :embeddable_host_tags, :tag_id
    add_index :embeddable_host_tags, %i[embeddable_host_id tag_id], unique: true
  end
end
