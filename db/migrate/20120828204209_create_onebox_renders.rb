class CreateOneboxRenders < ActiveRecord::Migration[4.2]
  def change
    create_table :onebox_renders do |t|
      t.string :url, null: false
      t.text :cooked, null: false
      t.datetime :expires_at, null: false
      t.timestamps null: false
    end

    add_index :onebox_renders, :url, unique: true
  end
end
