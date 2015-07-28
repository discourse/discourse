class CreateUserFieldOptions < ActiveRecord::Migration
  def change
    create_table :user_field_options, force: true do |t|
      t.references :user_field, null: false
      t.string :value, null: false
      t.timestamps
    end
  end
end
