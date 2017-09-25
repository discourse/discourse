class AddThemeRemoteFields < ActiveRecord::Migration[4.2]
  def change
    create_table :remote_themes do |t|
      t.string :remote_url, null: false
      t.string :remote_version
      t.string :local_version
      t.string :about_url
      t.string :license_url
      t.integer :commits_behind
      t.datetime :remote_updated_at
      t.timestamps null: false
    end

    add_column :themes, :remote_theme_id, :integer
    add_index :themes, :remote_theme_id, unique: true
  end
end
