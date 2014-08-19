# This migration comes from tagger (originally 20140312105850)
class CreateTaggerTags < ActiveRecord::Migration
  def up
    create_table :tagger_tags do |t|
      t.string :title

      t.timestamps
    end

    create_table :tagger_tags_topics, id: false do |t|
      t.integer :topic_id
      t.integer :tag_id

      # t.timestamps
    end

    add_index :tagger_tags_topics, [:topic_id, :tag_id], :unique => true
  end

  def down
    drop_table :tagger_tags
    drop_table :tagger_tags_topics
    remove_index :tagger_tags_topics, [:topic_id, :tag_id]
  end

end
