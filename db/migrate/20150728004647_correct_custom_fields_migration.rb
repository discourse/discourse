class CorrectCustomFieldsMigration < ActiveRecord::Migration[4.2]
  def up
    execute <<SQL
      DROP INDEX index_post_custom_fields_on_name_and_value
SQL

    execute <<SQL
      CREATE INDEX index_post_custom_fields_on_name_and_value ON post_custom_fields USING btree (name, left(value, 200))
SQL
  end

  def down
    # nothing, no point rolling this back, we rewrote history
  end
end
