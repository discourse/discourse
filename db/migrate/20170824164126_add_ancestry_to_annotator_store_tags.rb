class AddAncestryToAnnotatorStoreTags < ActiveRecord::Migration
  def change
    add_column :annotator_store_tags, :ancestry, :string
    add_index :annotator_store_tags, :ancestry
  end
end
