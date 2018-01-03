class AddUploadIdToThemeFields < ActiveRecord::Migration[4.2]
  def up
    remove_index :theme_fields, [:theme_id, :target, :name]
    rename_column :theme_fields, :target, :target_id

    # we need a throwaway column here to keep running
    add_column :theme_fields, :target, :integer
    execute "UPDATE theme_fields SET target = target_id"

    change_column :theme_fields, :name, :string, null: false, limit: 30

    add_column :theme_fields, :upload_id, :integer
    add_column :theme_fields, :type_id, :integer, null: false, default: 0

    add_index :theme_fields, [:theme_id, :target_id, :type_id, :name], unique: true, name: 'theme_field_unique_index'
    execute "UPDATE theme_fields SET type_id = 1 WHERE name IN ('scss', 'embedded_scss')"
  end

  def down
    remove_column :theme_fields, :target
    execute 'drop index theme_field_unique_index'
    rename_column :theme_fields, :target_id, :target
    remove_column :theme_fields, :upload_id
    remove_column :theme_fields, :type_id
    add_index :theme_fields, [:theme_id, :target, :name], unique: true
  end
end
