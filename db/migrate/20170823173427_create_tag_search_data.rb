class CreateTagSearchData < ActiveRecord::Migration[4.2]
  def up
    create_table :tag_search_data, primary_key: :tag_id do |t|
      t.tsvector "search_data"
      t.text     "raw_data"
      t.text     "locale"
      t.integer  "version",     default: 0
    end
    execute 'create index idx_search_tag on tag_search_data using gin(search_data)'
  end

  def down
    execute 'drop index idx_search_tag'
    drop_table :tag_search_data
  end
end
