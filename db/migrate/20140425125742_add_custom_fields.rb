class AddCustomFields < ActiveRecord::Migration[4.2]
  def change
    create_table :category_custom_fields do |t|
      t.integer :category_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps null: false
    end

    create_table :group_custom_fields do |t|
      t.integer :group_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps null: false
    end

    create_table :post_custom_fields do |t|
      t.integer :post_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps null: false
    end

    add_index :category_custom_fields, [:category_id, :name]
    add_index :group_custom_fields, [:group_id, :name]
    add_index :post_custom_fields, [:post_id, :name]
  end
end
