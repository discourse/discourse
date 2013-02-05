class BioMarkdownSupport < ActiveRecord::Migration
  def up
    rename_column :users, :bio, :bio_raw
    add_column :users, :bio_cooked, :text, null: true

    User.where("bio_raw is NOT NULL").each do |u|
      u.send(:cook)
      u.save
    end

  end

  def down
    rename_column :users, :bio_raw, :bio
    remove_column :users, :bio_cooked
  end
end
