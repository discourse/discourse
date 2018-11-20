class BioMarkdownSupport < ActiveRecord::Migration[4.2]
  def up
    rename_column :users, :bio, :bio_raw
    add_column :users, :bio_cooked, :text, null: true
  end

  def down
    rename_column :users, :bio_raw, :bio
    remove_column :users, :bio_cooked
  end
end
