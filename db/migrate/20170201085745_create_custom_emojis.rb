class CreateCustomEmojis < ActiveRecord::Migration[4.2]
  def change
    create_table :custom_emojis do |t|
      t.string :name, null: false
      t.integer :upload_id, null: false

      t.timestamps null: false
    end

    add_index :custom_emojis, :name, unique: true
  end
end
