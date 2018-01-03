class AddSlugIndexOnTopic < ActiveRecord::Migration[4.2]
  def up
    execute 'CREATE INDEX idxTopicSlug ON topics(slug) WHERE deleted_at IS NULL AND slug IS NOT NULL'
  end

  def down
    execute 'DROP INDEX idxTopicSlug'
  end
end
