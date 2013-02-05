class CreateExpressionTypes < ActiveRecord::Migration
  def change
    create_table :expression_types do |t|
      t.integer :site_id, null: false
      t.string :name, null: false, limit: 50
      t.string :long_form, null: false, limit: 100
      t.timestamps
    end

    add_index :expression_types, [:site_id, :name], unique: true
  end
end
