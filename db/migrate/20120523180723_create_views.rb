class CreateViews < ActiveRecord::Migration
  def change
    create_table :views, id: false do |t|
      t.integer  :parent_id, null: false
      t.string   :parent_type, limit: 50, null: false
      t.integer  :ip, limit: 8, null: false
      t.datetime :viewed_at, null: false
      t.integer  :user_id, null: true
    end

    add_index :views, [:parent_id, :parent_type]
    add_index :views, [:parent_id, :parent_type, :ip, :viewed_at], unique: true, name: "unique_views"
  end
end
