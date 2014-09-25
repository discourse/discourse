class CreateUserFields < ActiveRecord::Migration
  def change
    create_table :user_fields do |t|
      t.string :name, null: false
      t.string :field_type, null: false
      t.timestamps
    end
  end
end
