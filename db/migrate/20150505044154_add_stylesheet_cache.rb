class AddStylesheetCache < ActiveRecord::Migration
  def change
    create_table :stylesheet_cache do |t|
      t.string :target, null: false
      t.string :digest, null: false
      t.text :content, null: false
      t.timestamps
    end

    add_index :stylesheet_cache, [:target, :digest], unique: true
  end
end
