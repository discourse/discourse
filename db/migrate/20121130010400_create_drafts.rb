class CreateDrafts < ActiveRecord::Migration[4.2]
  def change
    create_table :drafts do |t|
      t.integer :user_id, null: false
      t.string :draft_key, null: false
      t.text :data, null: false
      t.timestamps null: false
    end
    add_index :drafts, [:user_id, :draft_key]
  end
end
