class CreateExpressions < ActiveRecord::Migration
  def change
    create_table :expressions, id: false, force: true do |t|
      t.integer :parent_id, null: false
      t.string :parent_type, null: false, limit: 50
      t.integer :expression_type_id, null: false
      t.integer :user_id, null: false
      t.timestamps
    end

    add_index :expressions, [:parent_id, :parent_type, :expression_type_id, :user_id], unique: true, name: "expressions_pk"
  end
end
