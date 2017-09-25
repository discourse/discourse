class AddIndexToPostCustomFields < ActiveRecord::Migration[4.2]
  def up
    execute <<SQL
      CREATE INDEX index_post_custom_fields_on_name_and_value ON post_custom_fields USING btree (name, left(value, 200))
SQL
  end

  def down
    execute <<SQL
      DROP INDEX index_post_custom_fields_on_name_and_value
SQL

  end
end
