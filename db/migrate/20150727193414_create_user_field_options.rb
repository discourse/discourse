class CreateUserFieldOptions < ActiveRecord::Migration[4.2]
  def change
    create_table :user_field_options, force: true do |t|
      t.references :user_field, null: false
      t.string :value, null: false
      t.timestamps null: false
    end
  end
end
