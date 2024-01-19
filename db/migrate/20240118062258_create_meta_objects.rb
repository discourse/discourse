class CreateMetaObjects < ActiveRecord::Migration[7.0]
  def change
    create_table :meta_objects do |t|
      t.bigint :meta_schema_id, null: false

      t.timestamps
    end

    create_table :meta_fields do |t|
      t.bigint :meta_object_id, null: false
      t.bigint :meta_column_id, null: false

      t.timestamps
    end

    add_index :meta_fields, %i[meta_object_id meta_column_id], unique: true

    create_table :string_meta_fields do |t|
      t.bigint :meta_field_id, null: false
      t.string :value, null: false, limit: 255

      t.timestamps
    end

    create_table :integer_meta_fields do |t|
      t.bigint :meta_field_id, null: false
      t.integer :value, null: false
    end

    create_table :enum_meta_fields do |t|
      t.bigint :meta_field_id, null: false
      t.string :value, null: false, limit: 255
    end
  end
end
