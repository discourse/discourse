class CreateUserFields < ActiveRecord::Migration[4.2]
  def change
    create_table :user_fields do |t|
      t.string :name, null: false
      t.string :field_type, null: false
      t.timestamps null: false
    end
  end
end
