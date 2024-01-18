class CreateThemeMetaSchemas < ActiveRecord::Migration[7.0]
  def change
    create_table :meta_schemas do |t|
      t.string :name, null: false, limit: 255
      t.integer :theme_id, null: true

      t.timestamps
    end

    add_index :meta_schemas, %i[name theme_id], unique: true

    create_table :meta_field_types do |t|
      t.bigint :meta_schema_id, null: false
      t.string :name, null: false, limit: 255
      t.boolean :required, null: false, default: true
      t.string :type, null: false

      t.timestamps
    end

    add_index :meta_field_types, %i[name meta_schema_id], unique: true

    create_table :string_meta_field_types do |t|
      t.bigint :meta_field_type_id, null: false
      t.integer :min_length, null: false, default: 0
      t.integer :max_length, null: false, default: 255

      t.timestamps
    end

    create_table :integer_meta_field_types do |t|
      t.bigint :meta_field_type_id, null: false
      t.integer :min_value, null: false, default: 0
      t.integer :max_value, null: true

      t.timestamps
    end

    create_table :enum_meta_field_types do |t|
      t.bigint :meta_field_type_id, null: false
      t.string :values, array: true, null: false

      t.timestamps
    end
  end
end
